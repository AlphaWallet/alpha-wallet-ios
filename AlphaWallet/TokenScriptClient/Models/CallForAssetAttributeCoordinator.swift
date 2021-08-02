// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import Result
import web3swift

///This class temporarily stores the promises used to make function calls. This is so we don't make the same function calls (over network) + arguments combination multiple times concurrently. Once the call completes, we remove it from the cache.
class CallForAssetAttributeCoordinator {
    private let server: RPCServer
    private let assetDefinitionStore: AssetDefinitionStore
    private var promiseCache = ThreadSafeDictionary<AssetFunctionCall, Promise<AssetInternalValue>>()

    init(server: RPCServer, assetDefinitionStore: AssetDefinitionStore) {
        self.server = server 
        self.assetDefinitionStore = assetDefinitionStore
    }

    func getValue(
            forAttributeId attributeId: AttributeId,
            tokenId: TokenId,
            functionCall: AssetFunctionCall
    ) -> Subscribable<AssetInternalValue> {
        let subscribable = Subscribable<AssetInternalValue>(nil)
        if let promise = promiseCache[functionCall] {
            promise.done { result in
                subscribable.value = result
            }.cauterize()
            return subscribable
        }

        let promise = makeRpcPromise(forAttributeId: attributeId, tokenId: tokenId, functionCall: functionCall)
        promiseCache[functionCall] = promise

        //TODO need to throttle smart contract function calls?
        promise.done { [weak self] result in
            guard let strongSelf = self else { return }
            subscribable.value = result
            strongSelf.promiseCache.removeValue(forKey: functionCall)
        }.catch { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.promiseCache.removeValue(forKey: functionCall)
        }

        return subscribable
    }

    private func makeRpcPromise(
            forAttributeId attributeId: AttributeId?,
            tokenId: TokenId,
            functionCall: AssetFunctionCall) -> Promise<AssetInternalValue> {
        return Promise<AssetInternalValue> { seal in
            guard let function = CallForAssetAttribute(functionName: functionCall.functionName, inputs: functionCall.inputs, output: functionCall.output) else {
                seal.reject(AnyError(Web3Error(description: "Failed to create CallForAssetAttribute instance for function: \(functionCall.functionName)")))
                return
            }
            let contract = functionCall.contract

            //Fine to store a strong reference to self here because it's still useful to cache the function call result
            callSmartContract(withServer: server, contract: contract, functionName: functionCall.functionName, abiString: "[\(function.abi)]", parameters: functionCall.arguments).done { dictionary in
                if let value = dictionary["0"] {
                    switch functionCall.output.type {
                    case .address:
                        if let value = value as? EthereumAddress {
                            let result = AlphaWallet.Address(address: value)
                            seal.fulfill(.address(result))
                        }
                    case .bool:
                        let result = value as? Bool ?? false
                        seal.fulfill(.bool(result))
                    case .bytes, .bytes1, .bytes2, .bytes3, .bytes4, .bytes5, .bytes6, .bytes7, .bytes8, .bytes9, .bytes10, .bytes11, .bytes12, .bytes13, .bytes14, .bytes15, .bytes16, .bytes17, .bytes18, .bytes19, .bytes20, .bytes21, .bytes22, .bytes23, .bytes24, .bytes25, .bytes26, .bytes27, .bytes28, .bytes29, .bytes30, .bytes31, .bytes32:
                        let result = value as? Data ?? Data()
                        seal.fulfill(.bytes(result))
                    case .string:
                        let result = value as? String ?? ""
                        seal.fulfill(.string(result))
                    case .uint, .uint8, .uint16, .uint24, .uint32, .uint40, .uint48, .uint56, .uint64, .uint72, .uint80, .uint88, .uint96, .uint104, .uint112, .uint120, .uint128, .uint136, .uint144, .uint152, .uint160, .uint168, .uint176, .uint184, .uint192, .uint200, .uint208, .uint216, .uint224, .uint232, .uint240, .uint248, .uint256:
                        let result = value as? BigUInt ?? BigUInt(0)
                        seal.fulfill(.uint(result))
                    case .int, .int8, .int16, .int24, .int32, .int40, .int48, .int56, .int64, .int72, .int80, .int88, .int96, .int104, .int112, .int120, .int128, .int136, .int144, .int152, .int160, .int168, .int176, .int184, .int192, .int200, .int208, .int216, .int224, .int232, .int240, .int248, .int256:
                        let result = value as? BigInt ?? BigInt(0)
                        seal.fulfill(.int(result))
                    case .void:
                        //Don't expect to reach here
                        seal.fulfill(.bool(false))
                    }
                } else {
                    if case SolidityType.void = functionCall.output.type {
                        seal.fulfill(.bool(false))
                    } else {
                        seal.reject(Web3Error(description: "nil result from calling: \(function.name)() on contract: \(functionCall.contract.eip55String)"))
                    }
                }
            }.catch {
                seal.reject(AnyError($0))
            }
        }
    }
}
