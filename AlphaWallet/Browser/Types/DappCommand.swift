// Copyright DApps Platform Inc. All rights reserved.

import Foundation

struct DappCommand: Decodable {
    let name: Method
    let id: Int
    let object: [String: DappCommandObjectValue]
}

struct DappCallback {
    let id: Int
    let value: DappCallbackValue
}

enum DappCallbackValue {
    case signTransaction(Data)
    case sentTransaction(Data)
    case signMessage(Data)
    case signPersonalMessage(Data)
    case signTypedMessage(Data)
    case signTypedMessageV3(Data)
    case ethCall(String)

    var object: String {
        switch self {
        case .signTransaction(let data):
            return data.hexEncoded
        case .sentTransaction(let data):
            return data.hexEncoded
        case .signMessage(let data):
            return data.hexEncoded
        case .signPersonalMessage(let data):
            return data.hexEncoded
        case .signTypedMessage(let data):
            return data.hexEncoded
        case .signTypedMessageV3(let data):
            return data.hexEncoded
        case .ethCall(let value):
            return value
        }
    }
}

struct DappCommandObjectValue: Decodable {
    var value: String = ""
    var eip712PreV3Array: [EthTypedData] = []
    let eip712v3And4Data: EIP712TypedData?

    init(from coder: Decoder) throws {
        let container = try coder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = String(intValue)
            eip712v3And4Data = nil
        } else if let stringValue = try? container.decode(String.self) {
            if let data = stringValue.data(using: .utf8), let object = try? JSONDecoder().decode(EIP712TypedData.self, from: data) {
                value = ""
                eip712v3And4Data = object
            } else {
                value = stringValue
                eip712v3And4Data = nil
            }
        } else {
            var arrayContainer = try coder.unkeyedContainer()
            while !arrayContainer.isAtEnd {
                eip712PreV3Array.append(try arrayContainer.decode(EthTypedData.self))
            }
            eip712v3And4Data = nil
        }
    }
}
