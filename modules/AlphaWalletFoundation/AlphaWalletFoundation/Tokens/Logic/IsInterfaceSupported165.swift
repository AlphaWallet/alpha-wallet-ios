//
// Created by James Sangalli on 20/11/19.
//

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletWeb3

public actor IsInterfaceSupported165 {
    private let fileName: String
    private lazy var storage: Storage<[String: Bool]> = .init(fileName: fileName, storage: FileStorage(fileExtension: "json"), defaultValue: [:])

    private var inFlightTasks: [String: Task<Bool, Error>] = [:]

    private let blockchainProvider: BlockchainProvider

    public init(blockchainProvider: BlockchainProvider, fileName: String = "isInterfaceSupported165") {
        self.blockchainProvider = blockchainProvider
        self.fileName = fileName
    }

    private func setTask(_ task: Task<Bool, Error>?, forKey key: String) {
        inFlightTasks[key] = task
    }

    private func setStorageValue(_ value: Bool?, forKey key: String) {
        storage.value[key] = value
    }

    public nonisolated func getInterfaceSupported165(hash: String, contract: AlphaWallet.Address) async throws -> Bool {
        let key = "\(hash)-\(contract)-\(blockchainProvider.server)"
        if let value = await storage.value[key] {
            return value
        }
        if let task = await inFlightTasks[key] {
            return try await task.value
        } else {
            let task = Task<Bool, Error> {
                let result: SupportsInterfaceMethodCall.Response
                do {
                    result = try await blockchainProvider.callAsync(SupportsInterfaceMethodCall(contract: contract, hash: hash))
                } catch let error as Web3Error {
                    if isNodeErrorExecutionReverted(error: error) {
                        result = false
                    } else {
                        throw error
                    }
                }
                await setStorageValue(result, forKey: key)
                await setTask(nil, forKey: key)
                return result
            }
            await setTask(task, forKey: key)
            return try await task.value
        }
    }
}

func isNodeErrorExecutionReverted(error: Error) -> Bool {
    if case Web3Error.nodeError(let message) = error {
        if message.contains("execution reverted") {
            return true
        } else {
            return false
        }
    } else {
        return false
    }
}
