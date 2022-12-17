// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import AlphaWalletCore

final class GetBlockTimestamp {
    private let fileName: String
    private lazy var storage: Storage<[String: Date]> = .init(fileName: fileName, storage: FileStorage(fileExtension: "json"), defaultValue: [:])
    private var inFlightPromises: [String: Promise<Date>] = [:]

    private let rpcApiProvider: RpcApiProvider

    init(fileName: String = "blockTimestampStorage", rpcApiProvider: RpcApiProvider) {
        self.fileName = fileName
        self.rpcApiProvider = rpcApiProvider
    }

    func getBlockTimestamp(for blockNumber: BigUInt, server: RPCServer) -> Promise<Date> {
        firstly {
            .value(blockNumber)
        }.then { [weak self, queue, storage, rpcApiProvider] blockNumber -> Promise<Date> in
            let key = "\(blockNumber)-\(server)"
            if let value = storage.value[key] {
                return .value(value)
            }

            if let promise = self?.inFlightPromises[key] {
                return promise
            } else {
                let request = JsonRpcRequest(server: server, request: BlockByNumberRequest(number: blockNumber))

                let promise = firstly {
                    rpcApiProvider.dataTaskPromise(request)
                }.map{
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

