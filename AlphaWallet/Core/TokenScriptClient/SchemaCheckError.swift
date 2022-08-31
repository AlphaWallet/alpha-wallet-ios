//
//  SchemaCheckError.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import Foundation

struct SchemaCheckError: LocalizedError {
    var msg: String
    var errorDescription: String? {
        return msg
    }
}

enum OpenURLError: Error {
    case unsupportedTokenScriptVersion
    case copyTokenScriptURL(_ url: URL, _ destinationURL: URL, error: Error)
}
