// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import AlphaWalletCore

public class GetErc875Balance {
    private let queue = DispatchQueue(label: "org.alphawallet.swift.getErc875Balance")
    private var inFlightPromises: [String: Promise<[String]>] = [:]
    private let server: RPCServer

    public init(forServer server: RPCServer) {
        self.server = server
    }

    public func getErc875TokenBalance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) -> Promise<[String]> {
        firstly {
            .value(contract)
        }.then(on: queue, { [weak self, queue, server] contract -> Promise<[String]> in
            let key = "\(address.eip55String)-\(contract.eip55String)"
            
            if let promise = self?.inFlightPromises[key] {
                return promise
            } else {
                let function = GetERC875Balance()
                let promise = attempt(maximumRetryCount: 2, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) {
                    callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [address.eip55String] as [AnyObject])
                        .map(on: queue, { balanceResult -> [String] in
                            return GetErc875Balance.adapt(balanceResult["0"])
                        })
                }.ensure(on: queue, {
                    self?.inFlightPromises[key] = .none
                })

                self?.inFlightPromises[key] = promise

                return promise
            }
        })
    }

    private static func adapt(_ values: Any?) -> [String] {
        guard let array = values as? [Data] else { return [] }
        return array.map { each in
            let value = each.toHexString()
            return "0x\(value)"
        }
    }
}
