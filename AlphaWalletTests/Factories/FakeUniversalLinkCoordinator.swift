//
//  FakeUniversalLinkCoordinator.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 26.07.2022.
//

import Foundation
import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class FakeUniversalLinkCoordinator: UniversalLinkService {
    override func handleUniversalLink(url: URL, source: UrlSource) -> Bool { return false }
    override func handlePendingUniversalLink(in coordinator: UrlSchemeResolver) {}
    override func handleUniversalLinkInPasteboard() {}

    static func make() -> FakeUniversalLinkCoordinator {
        return .init(analytics: FakeAnalyticsService())
    }
}
