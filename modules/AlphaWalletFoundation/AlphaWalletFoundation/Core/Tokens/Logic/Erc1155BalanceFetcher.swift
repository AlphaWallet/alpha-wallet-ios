// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import web3swift

///Fetching ERC1155 tokens in 2 steps:
///
///A. Fetch known contracts and tokenIds owned (now or previously) for each, writing them to JSON. tokenIds are never removed (so we can easily discover their balance is 0 in the next step)
///B. Fetch balance for each tokenId owned (now or previously. For the latter value would be 0)
///
///This class performs (B)
public class Erc1155BalanceFetcher {
    private let address: AlphaWallet.Address
    private let server: RPCServer

    public init(address: AlphaWallet.Address, server: RPCServer) {
        self.address = address
        self.server = server
    }

    public func fetch(contract: AlphaWallet.Address, tokenIds: Set<BigInt>) -> Promise<[BigInt: BigUInt]> {
        //tokenIds must be unique (hence arg is a Set) so `Dictionary(uniqueKeysWithValues:)` wouldn't crash
        let tokenIds = Array(tokenIds)
        let address = EthereumAddress(self.address.eip55String)!
        let addresses: [EthereumAddress] = [EthereumAddress](repeating: address, count: tokenIds.count)
        return firstly {
            callSmartContract(withServer: server, contract: contract, functionName: "balanceOfBatch", abiString: AlphaWallet.Ethereum.ABI.erc1155String, parameters: [addresses, tokenIds] as [AnyObject])
        }.map { result in
            if let balances = result["0"] as? [BigUInt], balances.count == tokenIds.count {
                return Dictionary(uniqueKeysWithValues: zip(tokenIds, balances))
            } else {
                throw createABIError(.invalidArgumentType)
            }
        }
    }
}
