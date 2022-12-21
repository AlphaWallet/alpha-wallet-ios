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

class FakeSessionFactory: SessionFactory {
    var networkService: NetworkService = FakeNetworkService()
    var analytics: AnalyticsLogger = FakeAnalyticsService()
    var rpcApiProvider: BaseRpcApiProvider = BaseRpcApiProvider(analytics: FakeAnalyticsService(), networkService: FakeNetworkService())
    var config: Config = .make()
    var nodeApiProvider: NodeApiProvider?
    var httpParam: RpcHttpParams = .init(rpcUrls: [
        URL(string: "http://google.com")!
    ], headers: [:])

    func buildSession(server: RPCServer, wallet: Wallet) -> WalletSession {
        let nodeApiProvider: NodeApiProvider = NodeRpcApiProvider(
            rpcApiProvider: rpcApiProvider,
            server: server,
            rpcHttpParams: httpParam)

        let blockchainProvider: BlockchainProvider = RpcBlockchainProvider(
            server: server,
            account: wallet,
            nodeApiProvider: nodeApiProvider,
            analytics: analytics,
            params: .defaultParams(for: server))

        return WalletSession(
            account: wallet,
            server: server,
            config: config,
            analytics: analytics,
            blockchainProvider: blockchainProvider)
    }
}

final class FakeSessionsProvider: SessionsProvider {

    init(servers: [RPCServer]) {
        let factory = FakeSessionFactory()
        super.init(config: .make(defaults: .standardOrForTests, enabledServers: servers), factory: factory)
    }
}
