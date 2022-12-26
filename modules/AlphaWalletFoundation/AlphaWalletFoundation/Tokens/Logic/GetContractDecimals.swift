// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import AlphaWalletWeb3
import AlphaWalletCore

final class GetContractDecimals {
    private var inFlightPromises: [String: Promise<Int>] = [:]
    private let queue = DispatchQueue(label: "org.alphawallet.swift.getContractDecimals")

    private let blockchainProvider: BlockchainProvider

    init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }
    
    func getDecimals(for contract: AlphaWallet.Address) -> Promise<Int> {
        firstly {
            .value(contract)
        }.then(on: queue, { [weak self, queue, blockchainProvider] contract -> Promise<Int> in
            let key = contract.eip55String
            
            if let promise = self?.inFlightPromises[key] {
                return promise
            } else {
                let promise = blockchainProvider
                    .callPromise(Erc20DecimalsRequest(contract: contract))
                    .get {
                        print("xxx.erc20 decimals value: \($0)")
                    }.recover { e -> Promise<Int> in
                        print("xxx.erc20 decimals failure: \(e)")
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

struct Erc20DecimalsRequest: ContractMethodCall {
    typealias Response = Int

    let contract: AlphaWallet.Address
    var name: String = "decimals"
    var abi: String = Web3.Utils.erc20ABI
    var parameters: [AnyObject] { [] }

    init(contract: AlphaWallet.Address) {
        self.contract = contract
    }

    func response(from resultObject: Any) throws -> Int {
        guard let dictionary = resultObject as? [String: AnyObject] else {
            throw CastError(actualValue: resultObject, expectedType: [String: AnyObject].self)
        }

        guard let decimalsOfUnknownType = dictionary["0"], let decimals = Int(String(describing: decimalsOfUnknownType)) else {
            throw CastError(actualValue: dictionary["0"], expectedType: Int.self)
        }

        return decimals
    }
}
