// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import AlphaWalletWeb3
import AlphaWalletCore

final class GetContractSymbol {
    private let server: RPCServer
    private var inFlightPromises: [String: Promise<String>] = [:]
    private let queue = DispatchQueue(label: "org.alphawallet.swift.getContractSymbol")

    init(forServer server: RPCServer) {
        self.server = server
    }

    func getSymbol(for contract: AlphaWallet.Address) -> Promise<String> {
        firstly {
            .value(contract)
        }.then(on: queue, { [weak self, queue, server] contract -> Promise<String> in
            let key = contract.eip55String
            
            if let promise = self?.inFlightPromises[key] {
                return promise
            } else {
                let promise = attempt(maximumRetryCount: 2, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) {
                    callSmartContract(withServer: server, contract: contract, functionName: "symbol", abiString: Web3.Utils.erc20ABI)
                        .map(on: queue, { symbolsResult -> String in
                            guard let symbol = symbolsResult["0"] as? String else {
                                throw CastError(actualValue: symbolsResult["0"], expectedType: String.self)
                            }
                            return symbol
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
