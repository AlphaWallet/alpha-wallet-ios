// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletWeb3
import BigInt
import PromiseKit

///This class temporarily stores the promises used to make function calls. This is so we don't make the same function calls (over network) + arguments combination multiple times concurrently. Once the call completes, we remove it from the cache.
public class CallForAssetAttributeProvider {
    private var inflightPromises: AtomicDictionary<AssetFunctionCall, Promise<AssetInternalValue>> = .init()
    private let blockchainsProvider: BlockchainsProvider

    public init(blockchainsProvider: BlockchainsProvider) {
        self.blockchainsProvider = blockchainsProvider
    }

    public func getValue(functionCall: AssetFunctionCall) -> Subscribable<AssetInternalValue> {
        let subscribable = Subscribable<AssetInternalValue>()
        if let promise = inflightPromises[functionCall] {
            promise.done { result in
                subscribable.send(result)
            }.cauterize()
            return subscribable
        }

        let promise = makeRpcPromise(functionCall: functionCall)
        inflightPromises[functionCall] = promise

        //TODO need to throttle smart contract function calls?
        promise.done { [weak self] result in
            guard let strongSelf = self else { return }
            subscribable.send(result)
            strongSelf.inflightPromises.removeValue(forKey: functionCall)
        }.catch { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.inflightPromises.removeValue(forKey: functionCall)
        }

        return subscribable
    }

    private func makeRpcPromise(functionCall: AssetFunctionCall) -> Promise<AssetInternalValue> {
        guard let function = CallForAssetAttribute(functionName: functionCall.functionName, inputs: functionCall.inputs, output: functionCall.output) else {
            return .init(error: Web3Error(description: "Failed to create CallForAssetAttribute instance for function: \(functionCall.functionName)"))
        }

        guard let blockchain = blockchainsProvider.blockchain(with: functionCall.server) else {
            return .init(error: Web3Error(description: "Failed to get blockchain of \(functionCall.server) for function: \(functionCall.functionName)"))
        }

        //Fine to store a strong reference to self here because it's still useful to cache the function call result
        return blockchain.call(AssetAttributeMethodCall(functionCall: functionCall, function: function), block: .latest).promise()
    }
}

