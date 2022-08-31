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
    static func identifier(fromFileName: String) -> TokenGroupIdentifierProtocol? {
        return nil
    }

    func identify(token: TokenGroupIdentifiable) -> TokenGroup {
        return .assets
    }
}
