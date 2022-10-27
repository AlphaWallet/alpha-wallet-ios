//
// Created by James Sangalli on 14/7/18.
// Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import BigInt
import PromiseKit
import AlphaWalletCore

final class GetErc721Balance {
    private let queue = DispatchQueue(label: "org.alphawallet.swift.getErc721Balance")
    private var inFlightPromises: [String: Promise<[String]>] = [:]
    private let server: RPCServer

    init(forServer server: RPCServer) {
        self.server = server
    }

    func getERC721TokenBalance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) -> Promise<[String]> {
        firstly {
            .value(contract)
        }.then(on: queue, { [weak self, queue, server] contract -> Promise<[String]> in
            let key = "\(address.eip55String)-\(contract.eip55String)"
            
            if let promise = self?.inFlightPromises[key] {
                return promise
            } else {
                let function = GetERC721Balance()
                let promise = attempt(maximumRetryCount: 2, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) {
                    callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [address.eip55String] as [AnyObject])
                        .map(on: queue, { balanceResult -> [String] in
                            let balance = GetErc721Balance.adapt(balanceResult["0"] as Any)
                            if balance >= Int.max {
                                throw CastError(actualValue: balanceResult["0"], expectedType: Int.self)
                            } else {
                                return [String](repeating: "0", count: Int(balance))
                            }
                        })
                }.ensure(on: queue, {
                    self?.inFlightPromises[key] = .none
                })

                self?.inFlightPromises[key] = promise

                return promise
            }
        })
    }

    private static func adapt(_ value: Any) -> BigUInt {
        if let value = value as? BigUInt {
            return value
        } else {
            return BigUInt(0)
        }
    }
}
