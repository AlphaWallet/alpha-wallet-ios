//
//  FakeSessionsProvider.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 26.07.2022.
//

import Foundation
import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

final class FakeSessionsProvider: SessionsProvider {
    init(servers: [RPCServer]) {
        super.init(config: .make(defaults: .standardOrForTests, enabledServers: servers), analytics: FakeAnalyticsService())
    }
}
