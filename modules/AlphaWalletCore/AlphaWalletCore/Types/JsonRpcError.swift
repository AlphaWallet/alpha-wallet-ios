// Copyright © 2023 Stormbird PTE. LTD.

import Foundation

public struct JsonRpcError: Error, Equatable, Codable {
    public let code: Int
    public let message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }
}

public extension JsonRpcError {
    static let invalidJson = JsonRpcError(code: -32700, message: "An error occurred on the server while parsing the JSON text.")
    static let invalidRequest = JsonRpcError(code: -32600, message: "The JSON sent is not a valid Request object.")
    static let methodNotFound = JsonRpcError(code: -32601, message: "The method does not exist / is not available.")
    static let invalidParams = JsonRpcError(code: -32602, message: "Invalid method parameter(s).")
    static let internalError = JsonRpcError(code: -32603, message: "Internal JSON-RPC error.")
    static let responseError = JsonRpcError(code: -32010, message: "Response error.")
    static let requestRejected = JsonRpcError(code: -32050, message: "Request rejected")

    static func unsupportedChain(chainId: String) -> JsonRpcError {
        JsonRpcError(code: 4902, message: "Unrecognized chain ID \(chainId). Try adding the chain using wallet_addEthereumChain first.")
    }

    static func internalError(message: String) -> JsonRpcError {
        JsonRpcError(code: -32603, message: message)
    }
}

extension JsonRpcError: LocalizedError {
    public var errorDescription: String? {
        return message
    }
}
