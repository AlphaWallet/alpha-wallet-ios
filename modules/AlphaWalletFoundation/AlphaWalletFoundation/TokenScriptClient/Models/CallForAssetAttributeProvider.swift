// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import AlphaWalletWeb3

///This class temporarily stores the promises used to make function calls. This is so we don't make the same function calls (over network) + arguments combination multiple times concurrently. Once the call completes, we remove it from the cache.
public class CallForAssetAttributeProvider {
    private var inFlightTasks: [AssetFunctionCall: LoaderTask<AssetInternalValue>] = [:]
    private let blockchainsProvider: BlockchainsProvider

    public init(blockchainsProvider: BlockchainsProvider) {
        self.blockchainsProvider = blockchainsProvider
    }

    public func getValue(functionCall: AssetFunctionCall) -> Subscribable<AssetInternalValue> {
        let subscribable = Subscribable<AssetInternalValue>(nil)
        Task {
            let result = try await self.resolve(functionCall: functionCall)
            subscribable.send(result)
        }

        return subscribable
    }

    private func resolve(functionCall: AssetFunctionCall) async throws -> AssetInternalValue {
        if let status = inFlightTasks[functionCall] {
            switch status {
            case .fetched(let value):
                return value
            case .inProgress(let task):
                return try await task.value
            }
        }

        let task: Task<AssetInternalValue, Error> = Task {
            try await buildRpcCall(functionCall: functionCall)
        }

        inFlightTasks[functionCall] = .inProgress(task)
        let value = try await task.value
        inFlightTasks[functionCall] = .fetched(value)

        return value
    }

    private func buildRpcCall(functionCall: AssetFunctionCall) async throws -> AssetInternalValue {
        guard let function = CallForAssetAttribute(functionName: functionCall.functionName, inputs: functionCall.inputs, output: functionCall.output) else {
            throw Web3Error(description: "Failed to create CallForAssetAttribute instance for function: \(functionCall.functionName)")
        }

        guard let blockchain = blockchainsProvider.blockchain(with: functionCall.server) else {
            throw Web3Error(description: "Failed to get blockchain of \(functionCall.server) for function: \(functionCall.functionName)")
        }

        //Fine to store a strong reference to self here because it's still useful to cache the function call result
        return try await blockchain.call(AssetAttributeMethodCall(functionCall: functionCall, function: function), block: .latest)
    }
}
