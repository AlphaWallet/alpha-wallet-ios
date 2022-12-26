// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import AlphaWalletCore

final class GetBlockTimestamp {
    private let fileName: String
    private lazy var storage: Storage<[String: Date]> = .init(fileName: fileName, storage: FileStorage(fileExtension: "json"), defaultValue: [:])
    private var inFlightPromises: [String: Promise<Date>] = [:]

    private let sessionsProvider: SessionsProvider

    init(fileName: String = "blockTimestampStorage", sessionsProvider: SessionsProvider) {
        self.fileName = fileName
        self.sessionsProvider = sessionsProvider
    }

    func getBlockTimestamp(for blockNumber: BigUInt, server: RPCServer) -> Promise<Date> {
        firstly {
            .value(blockNumber)
        }.then { [weak self, storage, sessionsProvider] blockNumber -> Promise<Date> in
            let key = "\(blockNumber)-\(server)"
            if let value = storage.value[key] {
                return .value(value)
            }

            if let promise = self?.inFlightPromises[key] {
                return promise
            } else {
                guard let session = sessionsProvider.session(for: server) else { return .init(error: PMKError.cancelled) }

                let promise = firstly {
                    session.blockchainProvider.blockByNumberPromise(blockNumber: blockNumber)
                }.map {
                    $0.timestamp
                }.ensure {
                    self?.inFlightPromises[key] = .none
                }.get { date in
                    storage.value[key] = date
                }

                self?.inFlightPromises[key] = promise

                return promise
            }
        }
    }
}

