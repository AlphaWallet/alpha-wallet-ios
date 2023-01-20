// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import AlphaWalletWeb3

///This class temporarily stores the promises used to make function calls. This is so we don't make the same function calls (over network) + arguments combination multiple times concurrently. Once the call completes, we remove it from the cache.
public class CallForAssetAttributeProvider {
    private var inflightPromises: AtomicDictionary<AssetFunctionCall, Promise<AssetInternalValue>> = .init()
    private let blockchainsProvider: BlockchainsProvider

    public init(blockchainsProvider: BlockchainsProvider) {
        self.blockchainsProvider = blockchainsProvider
    }

    public func getValue(forAttributeId attributeId: AttributeId, functionCall: AssetFunctionCall) -> Subscribable<AssetInternalValue> {
        let subscribable = Subscribable<AssetInternalValue>(nil)
        if let promise = inflightPromises[functionCall] {
            promise.done { result in
                subscribable.send(result)
            }.cauterize()
            return subscribable
        }

        let promise = makeRpcPromise(forAttributeId: attributeId, functionCall: functionCall)
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

    private func makeRpcPromise(forAttributeId attributeId: AttributeId?, functionCall: AssetFunctionCall) -> Promise<AssetInternalValue> {
        guard let function = CallForAssetAttribute(functionName: functionCall.functionName, inputs: functionCall.inputs, output: functionCall.output) else {
            return .init(error: Web3Error(description: "Failed to create CallForAssetAttribute instance for function: \(functionCall.functionName)"))
        }

        return blockchainsProvider
            .callSmartContract(
                withServer: functionCall.server,
                contract: functionCall.contract,
                functionName: functionCall.functionName,
                abiString: "[\(function.abi)]",
                parameters: functionCall.arguments,
                shouldDelayIfCached: true)
            .map { dictionary in
                if let value = dictionary["0"] {
                    return CallForAssetAttributeProvider.functional.mapValue(of: functionCall.output, for: value)
                } else {
                    if case SolidityType.void = functionCall.output.type {
                        return .bool(false)
                    } else {
                        throw Web3Error(description: "nil result from calling: \(function.name)() on contract: \(functionCall.contract.eip55String)")
                    }
                }
            }
    }
}
