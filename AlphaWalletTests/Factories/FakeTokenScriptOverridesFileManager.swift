//
//  FakeTokenScriptOverridesFileManager.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 29.11.2022.
//

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

extension TokenScriptOverridesFileManager {
    static func fake() -> TokenScriptOverridesFileManager {
        return .init(rootDirectory: .cachesDirectory)
    }
}
