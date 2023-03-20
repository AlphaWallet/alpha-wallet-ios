// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import AlphaWalletWeb3
import AlphaWalletCore
import JSONRPCKit
import APIKit

extension JSONRPCKit.JSONRPCError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .responseError(_, let message, _):
            return message
        case .responseNotFound:
            return "Response Not Found"
        case .resultObjectParseError:
            return "Result Object Parse Error"
        case .errorObjectParseError:
            return "Error Object Parse Error"
        case .unsupportedVersion(let string):
            return "Unsupported Version \(string)"
        case .unexpectedTypeObject:
            return "Unexpected Type Object"
        case .missingBothResultAndError:
            return "Missing Both Result And Error"
        case .nonArrayResponse:
            return "Non Array Response"
        }
    }
}
