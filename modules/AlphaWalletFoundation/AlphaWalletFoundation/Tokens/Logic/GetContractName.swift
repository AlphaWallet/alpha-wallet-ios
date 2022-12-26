// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import AlphaWalletWeb3
import AlphaWalletCore

final class GetContractName {
    private let blockchainProvider: BlockchainProvider
    private var inFlightPromises: [String: Promise<String>] = [:]
    private let queue = DispatchQueue(label: "org.alphawallet.swift.getContractName")

    init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    func getName(for contract: AlphaWallet.Address) -> Promise<String> {
        firstly {
            .value(contract)
        }.then(on: queue, { [weak self, queue, blockchainProvider] contract -> Promise<String> in
            let key = contract.eip55String
            
            if let promise = self?.inFlightPromises[key] {
                return promise
            } else {
                let promise = blockchainProvider
                    .callPromise(Erc20NameRequest(contract: contract))
                    .get {
                        print("xxx.erc20 name value: \($0)")
                    }.recover { e -> Promise<String> in
                        print("xxx.erc20 name failure: \(e)")
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

struct Erc20NameRequest: ContractMethodCall {
    typealias Response = String

    let contract: AlphaWallet.Address
    let name: String = "name"
    let abi: String = Web3.Utils.erc20ABI

    init(contract: AlphaWallet.Address) {
        self.contract = contract
    }

    func response(from resultObject: Any) throws -> String {
        guard let dictionary = resultObject as? [String: AnyObject] else {
            throw CastError(actualValue: resultObject, expectedType: [String: AnyObject].self)
        }

        guard let name = dictionary["0"] as? String else {
            throw CastError(actualValue: dictionary["0"], expectedType: String.self)
        }
        return name
    }
}
