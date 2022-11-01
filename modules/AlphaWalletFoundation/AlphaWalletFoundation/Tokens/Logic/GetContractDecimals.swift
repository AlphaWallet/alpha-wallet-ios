// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import AlphaWalletWeb3
import AlphaWalletCore

final class GetContractDecimals {
    private let server: RPCServer
    private var inFlightPromises: [String: Promise<Int>] = [:]
    private let queue = DispatchQueue(label: "org.alphawallet.swift.getContractDecimals")

    init(forServer server: RPCServer) {
        self.server = server
    }
    
    func getDecimals(for contract: AlphaWallet.Address) -> Promise<Int> {
        firstly {
            .value(contract)
        }.then(on: queue, { [weak self, queue, server] contract -> Promise<Int> in
            let key = contract.eip55String
            
            if let promise = self?.inFlightPromises[key] {
                return promise
            } else {
                let promise = attempt(maximumRetryCount: 2, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) {
                    callSmartContract(withServer: server, contract: contract, functionName: "decimals", abiString: Web3.Utils.erc20ABI)
                        .map(on: queue, { dictionary -> Int in
                            guard let decimalsOfUnknownType = dictionary["0"], let decimals = Int(String(describing: decimalsOfUnknownType)) else {
                                throw CastError(actualValue: dictionary["0"], expectedType: Int.self)
                            }

                            return decimals
                        })
                }.ensure(on: queue, {
                    self?.inFlightPromises[key] = .none
                })

                self?.inFlightPromises[key] = promise

                return promise
            }
        })
    }
}
