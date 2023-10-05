//
//  SignMessageValidator.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 21.02.2023.
//

import Foundation
import AlphaWalletABI

public struct DappOrTokenScriptEip712v3And4Validator {
    let server: RPCServer
    let source: Analytics.SignMessageRequestSource

    public init(server: RPCServer, source: Analytics.SignMessageRequestSource) {
        self.server = server
        self.source = source
    }

    public func validate(message: EIP712TypedData) throws {
        if let requested = message.server, server != requested {
            throw SignMessageValidatorError.notMatchesToChainId(active: server, requested: requested, source: source)
        }
    }
}

public struct TypedMessageValidator {
    public init() { }

    public func validate(message: [EthTypedData]) throws {
        guard !message.isEmpty else { throw SignMessageValidatorError.emptyMessage }
    }
}

public enum SignMessageValidatorError: Error {
    case emptyMessage
    case notMatchesToChainId(active: RPCServer, requested: RPCServer, source: Analytics.SignMessageRequestSource)
    case notMatchesToAnyOfChainIds(active: [RPCServer], requested: RPCServer, source: Analytics.SignMessageRequestSource)
}
