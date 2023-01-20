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

extension BlockchainsProvider {
    static func make(servers: [RPCServer]) -> BlockchainsProvider {
        let networkService = FakeNetworkService()
        let analytics = FakeAnalyticsService()

        let config = Config.make(defaults: .standardOrForTests, enabledServers: servers)

        let blockchainFactory = BaseBlockchainFactory(
            config: config,
            analytics: analytics,
            networkService: networkService)

        let serversProvider = BaseServersProvider(config: config)

        let blockchainsProvider = BlockchainsProvider(
            serversProvider: serversProvider,
            blockchainFactory: blockchainFactory)

        blockchainsProvider.start()

        return blockchainsProvider
    }
}

final class FakeSessionsProvider: SessionsProvider {

    init(servers: [RPCServer]) {
        let analytics = FakeAnalyticsService()

        let config = Config.make(defaults: .standardOrForTests, enabledServers: servers)

        super.init(
            config: config,
            analytics: analytics,
            blockchainsProvider: BlockchainsProvider.make(servers: servers))
    }
}
