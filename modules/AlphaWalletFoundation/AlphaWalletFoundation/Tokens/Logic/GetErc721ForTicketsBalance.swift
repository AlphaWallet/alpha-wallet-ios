// Copyright © 2019 Stormbird PTE. LTD.

import Foundation 
import BigInt
import PromiseKit
import AlphaWalletCore

class GetErc721ForTicketsBalance {
    private let queue = DispatchQueue(label: "org.alphawallet.swift.getErc721ForTicketsBalance")
    private var inFlightPromises: [String: Promise<[String]>] = [:]
    private let server: RPCServer

    init(forServer server: RPCServer) {
        self.server = server
    }

    func getERC721ForTicketsTokenBalance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) -> Promise<[String]> {
        firstly {
            .value(contract)
        }.then(on: queue, { [weak self, queue, server] contract -> Promise<[String]> in
            let key = "\(address.eip55String)-\(contract.eip55String)"
            
            if let promise = self?.inFlightPromises[key] {
                return promise
            } else {
                let function = GetERC721ForTicketsBalance()
                let promise = attempt(maximumRetryCount: 2, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) {
                    return callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [address.eip55String] as [AnyObject])
                        .map(on: queue, { balanceResult in
                            return GetErc721ForTicketsBalance.adapt(balanceResult["0"])
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
        guard let array = values as? [BigUInt] else { return [] }
        return array.filter({ $0 != BigUInt(0) }).map { each in
            let value = each.serialize().hex()
            return "0x\(value)"
        }
    }
}
