//
// Created by James Sangalli on 20/11/19.
//

import Foundation
import Combine
import AlphaWalletCore

public actor IsInterfaceSupported165 {
    private let fileName: String
    private lazy var storage: Storage<[String: Bool]> = .init(fileName: fileName, storage: FileStorage(fileExtension: "json"), defaultValue: [:])
    private var inFlightTasks: [String: LoaderTask<Bool>] = [:]
    private let blockchainProvider: BlockchainProvider

    public init(blockchainProvider: BlockchainProvider, fileName: String = "isInterfaceSupported165") {
        self.blockchainProvider = blockchainProvider
        self.fileName = fileName
    }

    public func getInterfaceSupported165(hash: String, contract: AlphaWallet.Address) async throws -> Bool {
        let key = "\(hash)-\(contract)-\(blockchainProvider.server)"
        if let status = inFlightTasks[key] {
            switch status {
            case .fetched(let value):
                return value
            case .inProgress(let task):
                return try await task.value
            }
        }

        if let value = storage.value[key] {
            inFlightTasks[key] = .fetched(value)
            return value
        }

        let task: Task<Bool, Error> = Task {
            let supported = try await blockchainProvider.call(Erc20SupportsInterfaceMethodCall(contract: contract, hash: hash))
            storage.value[key] = supported

            return supported
        }

        inFlightTasks[key] = .inProgress(task)
        let value = try await task.value
        inFlightTasks[key] = .fetched(value)

        return value
    }
}
