// Copyright © 2021 Stormbird PTE. LTD.

import Foundation

extension RpcRequest {
    static func call(from: AlphaWallet.Address?, to: AlphaWallet.Address?, value: String?, data: String, block: BlockParameter) -> RpcRequest {
        var payload: [String: Any] = [
            "data": data
        ]
        if let to = to {
            payload["to"] = to.eip55String
        }
        if let from = from {
            payload["from"] = from.eip55String
        }
        if let value = value {
            payload["value"] = value
        }

        return RpcRequest(method: "eth_сall", params: RpcParams(params: [payload, block] as [Any]))
    }
}

struct DataDecoder {
    func decode(response: RpcResponse) throws -> Data {
        switch response.outcome {
        case .response(let value):
            let hex = try value.get(String.self)
            return Data(_hex: hex)
        case .error(let error):
            throw error
        }
    }
}

import AlphaWalletWeb3

struct ContractMethodCallDecoder<MethodCall: ContractMethodCall> {
    struct DecoderError: Error {
        let message: String
    }
    private let contract: Contract
    private let methodCall: MethodCall

    init(contract: Contract, methodCall: MethodCall) {
        self.methodCall = methodCall
        self.contract = contract
    }
    
    func decode(response: RpcResponse) throws -> MethodCall.Response {
        switch response.outcome {
        case .response(let value):
            let hex = try value.get(String.self)

            guard let data = Data.fromHex(hex) else {
                throw CastError(actualValue: value.value, expectedType: Data.self)
            }

            guard let decodedData = contract.decodeReturnData(methodCall.name, data: data) else {
                throw DecoderError(message: "Can not decode returned parameters")
            }

            return try methodCall.response(from: decodedData)
        case .error(let error):
            throw error
        }
    }
}

