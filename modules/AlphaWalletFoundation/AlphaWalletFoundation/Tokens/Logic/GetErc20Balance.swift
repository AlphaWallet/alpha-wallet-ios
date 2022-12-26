// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import AlphaWalletWeb3
import AlphaWalletCore

final class GetErc20Balance {
    private var inFlightPromises: [String: Promise<BigInt>] = [:]
    private let queue = DispatchQueue(label: "org.alphawallet.swift.getErc20Balance")
    private let blockchainProvider: BlockchainProvider

    init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    func getErc20Balance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) -> Promise<BigInt> {
        firstly {
            .value(contract)
        }.then(on: queue, { [weak self, queue, blockchainProvider] contract -> Promise<BigInt> in
            let key = "\(address.eip55String)-\(contract.eip55String)"

            if let promise = self?.inFlightPromises[key] {
                return promise
            } else {
                let promise = blockchainProvider
                    .callPromise(Erc20BalanceOfRequest(contract: address, address: address))
                    .get {
                        print("xxx.erc20 balanceOf value: \($0)")
                    }.recover { e -> Promise<BigInt> in
                        print("xxx.erc20 balanceOf failure: \(e)")
                        throw e
                    }.ensure(on: queue, {
                        self?.inFlightPromises[key] = .none
                    })

                self?.inFlightPromises[key] = promise

                return promise
            }
        })
    }
}

struct Erc20BalanceOfRequest: ContractMethodCall {
    typealias Response = BigInt

    let contract: AlphaWallet.Address
    let name: String = "balanceOf"
    let abi: String = Web3.Utils.erc20ABI
    var parameters: [AnyObject] { [address.eip55String] as [AnyObject] }

    private let address: AlphaWallet.Address

    init(contract: AlphaWallet.Address, address: AlphaWallet.Address) {
        self.contract = contract
        self.address = address
    }

    func response(from resultObject: Any) throws -> BigInt {
        guard let dictionary = resultObject as? [String: AnyObject] else {
            throw CastError(actualValue: resultObject, expectedType: BigInt.self)
        }

        guard let balanceOfUnknownType = dictionary["0"], let balance = BigInt(String(describing: balanceOfUnknownType)) else {
            throw CastError(actualValue: dictionary["0"], expectedType: BigInt.self)
        }
        return balance
    }
}
