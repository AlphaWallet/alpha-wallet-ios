// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import AlphaWalletWeb3
import AlphaWalletCore

final class GetErc20Balance {
    private let server: RPCServer
    private var inFlightPromises: [String: Promise<BigInt>] = [:]
    private let queue = DispatchQueue(label: "org.alphawallet.swift.getErc20Balance")

    init(forServer server: RPCServer) {
        self.server = server
    }

    func getErc20Balance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) -> Promise<BigInt> {
        firstly {
            .value(contract)
        }.then(on: queue, { [weak self, queue, server] contract -> Promise<BigInt> in
            let key = "\(address.eip55String)-\(contract.eip55String)"
            
            if let promise = self?.inFlightPromises[key] {
                return promise
            } else {
                let promise = attempt(maximumRetryCount: 2, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) {
                    callSmartContract(withServer: server, contract: contract, functionName: "balanceOf", abiString: Web3.Utils.erc20ABI, parameters: [address.eip55String] as [AnyObject])
                        .map(on: queue, { balanceResult -> BigInt in
                            guard let balanceOfUnknownType = balanceResult["0"], let balance = BigInt(String(describing: balanceOfUnknownType)) else {
                                throw CastError(actualValue: balanceResult["0"], expectedType: BigInt.self)
                            }
                            return balance
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
