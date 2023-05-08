//
//  FakeTokenScriptOverridesFileManager.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 29.11.2022.
//

@testable import AlphaWallet
import AlphaWalletFoundation
import XCTest

extension TokenScriptOverridesFileManager {
    static func fake() -> TokenScriptOverridesFileManager {
        return .init(rootDirectory: .cachesDirectory)
    }
}
