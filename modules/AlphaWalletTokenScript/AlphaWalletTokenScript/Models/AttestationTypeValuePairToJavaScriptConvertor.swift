// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress
import AlphaWalletAttestation

public struct AttestationTypeValuePairToJavaScriptConvertor {
    public init() {}

    //Numbers must be formatted as string (or maybe later a suitable JavaScript big number type), but not as numbers in JavaScript because they can lose precision
    public func formatAsTokenScriptJavaScript(value: Attestation.TypeValuePair) -> String? {
        switch value.value {
        case .string(let string):
            let string = string.replacingOccurrences(of: "\"", with: "\\\"")
            if string.contains("\n") {
                //Multiple line JavaScript literals must be quoted with `` instead of single or double quotes
                return "`\(string.replacingOccurrences(of: "`", with: "\\`"))`"
            } else {
                return "\"\(string)\""
            }
        case .int(let int):
            return String(int)
        case .uint(let uint):
            return String(uint)
        case .address(let address):
            return "\"\(address.eip55String)\""
        case .bool(let bool):
            return bool ? "true" : "false"
        case .bytes(let bytes):
            return "\"\(bytes.hexEncoded)\""
        }
    }

    public static func formatAsTokenScriptJavaScriptGeneralisedTime(date: Date?) -> String {
        if let date {
            return "\(GeneralisedTime(date: date).formatAsTokenScriptJavaScript)"
        } else {
            return "null"
        }
    }

    public static func formatAsTokenScriptJavaScriptAddress(address: AlphaWallet.Address?) -> String {
        if let address {
            return "\"\(address.eip55String)\""
        } else {
            return "null"
        }
    }
}
