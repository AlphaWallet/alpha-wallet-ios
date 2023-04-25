//
//  FakeTokenGroupIdentifier.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

import Foundation
@testable import AlphaWallet
import AlphaWalletFoundation

final class FakeTokenGroupIdentifier: TokenGroupIdentifierProtocol {
    static func identifier(tokenJsonUrl: URL) -> TokenGroupIdentifierProtocol? {
        return nil
    }

    func identify(token: TokenGroupIdentifiable) -> TokenGroup {
        return .assets
    }

    func hasContract(address: String, chainID: Int) -> Bool {
        return false
    }

    func isSpam(address: String, chainID: Int) -> Bool {
        return false
    }
}
