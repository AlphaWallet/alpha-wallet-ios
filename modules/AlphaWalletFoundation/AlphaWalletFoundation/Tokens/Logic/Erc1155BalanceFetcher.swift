// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit 
import AlphaWalletWeb3

///Fetching ERC1155 tokens in 2 steps:
///
///A. Fetch known contracts and tokenIds owned (now or previously) for each, writing them to JSON. tokenIds are never removed (so we can easily discover their balance is 0 in the next step)
///B. Fetch balance for each tokenId owned (now or previously. For the latter value would be 0)
///
///This class performs (B)
final class Erc1155BalanceFetcher {
    private let address: AlphaWallet.Address
    private let server: RPCServer
    private var inFlightPromises: [String: Promise<[BigInt: BigUInt]>] = [:]
    private let queue = DispatchQueue(label: "org.alphawallet.swift.erc1155BalanceFetcher")

    init(address: AlphaWallet.Address, server: RPCServer) {
        self.address = address
        self.server = server
    }

    func getErc1155Balance(contract: AlphaWallet.Address, tokenIds: Set<BigInt>) -> Promise<[BigInt: BigUInt]> {
        firstly {
            .value(contract)
        }.then(on: queue, { [weak self, queue, address, server] contract -> Promise<[BigInt: BigUInt]> in
            let key = "\(contract.eip55String)-\(tokenIds.hashValue)"
            
            if let promise = self?.inFlightPromises[key] {
                return promise
            } else {
                //tokenIds must be unique (hence arg is a Set) so `Dictionary(uniqueKeysWithValues:)` wouldn't crash
                let tokenIds = Array(tokenIds)
                let address = EthereumAddress(address.eip55String)!
                let addresses: [EthereumAddress] = [EthereumAddress](repeating: address, count: tokenIds.count)
                let promise: Promise<[BigInt: BigUInt]> = firstly {
                    callSmartContract(withServer: server, contract: contract, functionName: "balanceOfBatch", abiString: AlphaWallet.Ethereum.ABI.erc1155String, parameters: [addresses, tokenIds] as [AnyObject])
                }.map(on: queue, { result in
                    guard let balances = result["0"] as? [BigUInt], balances.count == tokenIds.count else {
                        throw CastError(actualValue: result["0"], expectedType: [BigUInt].self)
                    }
                    return Dictionary(uniqueKeysWithValues: zip(tokenIds, balances))
                }).ensure(on: queue, {
                    self?.inFlightPromises[key] = .none
                })

                self?.inFlightPromises[key] = promise

                return promise
            }
        })
    }
}
