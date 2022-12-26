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
    private var inFlightPromises: [String: Promise<[BigInt: BigUInt]>] = [:]
    private let queue = DispatchQueue(label: "org.alphawallet.swift.erc1155BalanceFetcher")

    private let blockchainProvider: BlockchainProvider

    init(address: AlphaWallet.Address, blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
        self.address = address
    }

    func getErc1155Balance(contract: AlphaWallet.Address, tokenIds: Set<BigInt>) -> Promise<[BigInt: BigUInt]> {
        firstly {
            .value(contract)
        }.then(on: queue, { [weak self, queue, address, blockchainProvider] contract -> Promise<[BigInt: BigUInt]> in
            let key = "\(contract.eip55String)-\(tokenIds.hashValue)"
            
            if let promise = self?.inFlightPromises[key] {
                return promise
            } else {
                //tokenIds must be unique (hence arg is a Set) so `Dictionary(uniqueKeysWithValues:)` wouldn't crash
                let promise = blockchainProvider
                    .callPromise(Erc1155BalanceOfBatchRequest(contract: contract, address: address, tokenIds: tokenIds))
                    .ensure(on: queue, {
                        self?.inFlightPromises[key] = .none
                    })

                self?.inFlightPromises[key] = promise

                return promise
            }
        })
    }
}

struct Erc1155BalanceOfBatchRequest: ContractMethodCall {
    typealias Response = [BigInt: BigUInt]

    private let tokenIds: Set<BigInt>
    private let address: AlphaWallet.Address

    let contract: AlphaWallet.Address
    let name: String = "balanceOfBatch"
    let abi: String = AlphaWallet.Ethereum.ABI.erc1155String
    var parameters: [AnyObject] {
        let address = EthereumAddress(address.eip55String)!
        let addresses: [EthereumAddress] = [EthereumAddress](repeating: address, count: tokenIds.count)
        return [addresses, Array(tokenIds)] as [AnyObject]
    }

    init(contract: AlphaWallet.Address, address: AlphaWallet.Address, tokenIds: Set<BigInt>) {
        self.contract = contract
        self.address = address
        self.tokenIds = tokenIds
    }

    func response(from resultObject: Any) throws -> [BigInt: BigUInt] {
        guard let dictionary = resultObject as? [String: AnyObject] else {
            throw CastError(actualValue: resultObject, expectedType: [String: AnyObject].self)
        }

        guard let balances = dictionary["0"] as? [BigUInt], balances.count == tokenIds.count else {
            throw CastError(actualValue: dictionary["0"], expectedType: [BigUInt].self)
        }

        return Dictionary(uniqueKeysWithValues: zip(tokenIds, balances))
    }
}
