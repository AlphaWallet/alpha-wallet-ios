//
//  SchemaCheckError.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import Foundation

public struct SchemaCheckError: LocalizedError {
    var msg: String
    public var errorDescription: String? {
        return msg
    }
}

public enum OpenURLError: Error {
    case unsupportedTokenScriptVersion
    case copyTokenScriptURL(_ url: URL, _ destinationURL: URL, error: Error)
}
