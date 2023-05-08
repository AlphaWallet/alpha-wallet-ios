//
//  FakeUniversalLinkCoordinator.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 26.07.2022.
//

@testable import AlphaWallet
import AlphaWalletFoundation
import Foundation
import XCTest

class FakeUniversalLinkCoordinator: UniversalLinkService {
    weak var navigation: UniversalLinkNavigatable?

    func handleUniversalLink(url: URL, source: UrlSource) -> Bool { return false }

    static func make() -> FakeUniversalLinkCoordinator {
        return .init()
    }
}
