// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import TrustKeystore

enum DappAction {
    case signMessage(String)
    case signPersonalMessage(String)
    case signTransaction(UnconfirmedTransaction)
    case sendTransaction(UnconfirmedTransaction)
    case unknown
}

extension DappAction {
    static func fromCommand(_ command: DappCommand) -> DappAction {
        NSLog("command.name \(command.name)")
        NSLog("command.object \(command.object)")
        switch command.name {
        case .signTransaction:
            return .signTransaction(DappAction.makeUnconfirmedTransaction(command.object))
        case .sendTransaction:
            return .sendTransaction(DappAction.makeUnconfirmedTransaction(command.object))
        case .signMessage:
            let data = command.object["data"]?.value ?? ""
            return .signMessage(data)
        case .signPersonalMessage:
            let data = command.object["data"]?.value ?? ""
            return .signPersonalMessage(data)
        case .unknown:
            return .unknown
        }
    }

    private static func makeUnconfirmedTransaction(_ object: [String: DappCommandObjectValue]) -> UnconfirmedTransaction {
        let to = Address(string: object["to"]?.value ?? "")
        let value = BigInt((object["value"]?.value ?? "0").drop0x, radix: 16) ?? BigInt()
        let nonce = BigInt((object["nonce"]?.value ?? "0").drop0x, radix: 16) ?? BigInt()
        //let indices = (object["indices"]?.value ?? "0").drop0x) as [UInt16]
        let gasLimit: BigInt? = {
            guard let value = object["gasLimit"]?.value ?? object["gas"]?.value else { return .none }
            return BigInt((value).drop0x, radix: 16)
        }()
        let gasPrice: BigInt? = {
            guard let value = object["gasPrice"]?.value else { return .none }
            return BigInt((value).drop0x, radix: 16)
        }()
        let data = Data(hex: object["data"]?.value ?? "0x")

        return UnconfirmedTransaction(
            transferType: .ether(destination: .none),
            value: value,
            to: to,
            data: data,
            gasLimit: gasLimit,
            gasPrice: gasPrice,
            nonce: nonce,
            v: .none,
            r: .none,
            s: .none,
            expiry: .none,
            indices: .none
        )
    }
}
