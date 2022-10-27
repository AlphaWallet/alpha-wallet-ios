// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit 
import AlphaWalletWeb3
import AlphaWalletCore

final class GetBlockTimestamp {
    private let fileName: String
    private let queue = DispatchQueue(label: "org.alphawallet.swift.getBlockTimestamp")
    private lazy var storage: Storage<[String: Date]> = .init(fileName: fileName, storage: FileStorage(fileExtension: "json"), defaultValue: [:])
    private var inFlightPromises: [String: Promise<Date>] = [:]

    init(fileName: String = "blockTimestampStorage") {
        self.fileName = fileName
    }

    func getBlockTimestamp(for blockNumber: BigUInt, server: RPCServer) -> Promise<Date> {
        firstly {
            .value(blockNumber)
        }.then(on: queue, { [weak self, queue, storage] blockNumber -> Promise<Date> in
            let key = "\(blockNumber)-\(server)"
            if let value = storage.value[key] {
                return .value(value)
            }

            if let promise = self?.inFlightPromises[key] {
                return promise
            } else {
                let eth = Web3.Eth(web3: try Web3.instance(for: server, timeout: 6))
                let promise: Promise<Date> = firstly {
                    eth.getBlockByNumberPromise(blockNumber)
                }.map(on: queue, {
                    $0.timestamp
                }).ensure(on: queue, {
                    self?.inFlightPromises[key] = .none
                }).get(on: queue, { date in
                    storage.value[key] = date
                })

                self?.inFlightPromises[key] = promise

                return promise
            }
        })
    }
}

