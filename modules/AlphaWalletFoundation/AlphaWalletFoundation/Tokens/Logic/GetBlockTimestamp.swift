// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import AlphaWalletWeb3
import AlphaWalletCore
import JSONRPCKit
import APIKit

final class GetBlockTimestamp {
    private let fileName: String
    private lazy var storage: Storage<[String: Date]> = .init(fileName: fileName, storage: FileStorage(fileExtension: "json"), defaultValue: [:])
    private var inFlightPromises: [String: Promise<Date>] = [:]
    private let analytics: AnalyticsLogger

    init(fileName: String = "blockTimestampStorage", analytics: AnalyticsLogger) {
        self.fileName = fileName
        self.analytics = analytics
    }

    func getBlockTimestamp(for blockNumber: BigUInt, server: RPCServer) -> Promise<Date> {
        firstly {
            .value(blockNumber)
        }.then { [weak self, storage, analytics] blockNumber -> Promise<Date> in
            let key = "\(blockNumber)-\(server)"
            if let value = storage.value[key] {
                return .value(value)
            }

            if let promise = self?.inFlightPromises[key] {
                return promise
            } else {
                let request = EtherServiceRequest(server: server, batch: BatchFactory().create(BlockByNumberRequest(number: blockNumber)))
                let promise = firstly {
                    APIKitSession.send(request, server: server, analytics: analytics)
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

extension JSONRPCKit.JSONRPCError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .responseError(_, let message, _):
            return message
        case .responseNotFound:
            return "Response Not Found"
        case .resultObjectParseError:
            return "Result Object Parse Error"
        case .errorObjectParseError:
            return "Error Object Parse Error"
        case .unsupportedVersion(let string):
            return "Unsupported Version \(string)"
        case .unexpectedTypeObject:
            return "Unexpected Type Object"
        case .missingBothResultAndError:
            return "Missing Both Result And Error"
        case .nonArrayResponse:
            return "Non Array Response"
        }
    }
}
