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
import Combine

extension BlockchainsProvider {
    static func make(servers: [RPCServer]) -> BlockchainsProvider {
        let analytics = FakeAnalyticsService()

        let config = Config.make(defaults: .standardOrForTests, enabledServers: servers)

        let blockchainFactory = BaseBlockchainFactory(
            config: config,
            analytics: analytics)

        let serversProvider = BaseServersProvider(config: config)

        let blockchainsProvider = BlockchainsProvider(
            serversProvider: serversProvider,
            blockchainFactory: blockchainFactory)

        blockchainsProvider.start()

        return blockchainsProvider
    }
}

extension FakeSessionsProvider {
    static func make(wallet: Wallet = .make(), servers: [RPCServer] = [.main]) -> FakeSessionsProvider {
        let provider = FakeSessionsProvider(
            config: .make(),
            analytics: FakeAnalyticsService(),
            blockchainsProvider: .make(servers: servers),
            tokensDataStore: FakeTokensDataStore(servers: servers),
            assetDefinitionStore: .make(),
            reachability: FakeReachabilityManager(true),
            wallet: wallet,
            eventsDataStore: FakeEventsDataStore(account: wallet))

        provider.start()

        return provider
    }
}

class FakeSessionsProvider: SessionsProvider {
    private let sessionsSubject: CurrentValueSubject<ServerDictionary<WalletSession>, Never> = .init(.init())
    private let config: Config
    private var cancelable = Set<AnyCancellable>()
    private let blockchainsProvider: BlockchainsProvider
    private let analytics: AnalyticsLogger
    private let tokensDataStore: TokensDataStore
    private let assetDefinitionStore: AssetDefinitionStore
    private let reachability: ReachabilityManagerProtocol
    private let wallet: Wallet
    private let eventsDataStore: NonActivityEventsDataStore

    var sessions: AnyPublisher<ServerDictionary<WalletSession>, Never> {
        return sessionsSubject.eraseToAnyPublisher()
    }

    var activeSessions: ServerDictionary<WalletSession> {
        sessionsSubject.value
    }

    var contractDataFetcher: [RPCServer: ContractDataFetcher] = [:]
    var importToken: [RPCServer: ImportToken] = [:]

    convenience init(servers: [RPCServer]) {
        let config = Config.make(defaults: .standardOrForTests, enabledServers: servers)

        self.init(
            config: config,
            analytics: FakeAnalyticsService(),
            blockchainsProvider: BlockchainsProvider.make(servers: servers),
            tokensDataStore: FakeTokensDataStore(servers: servers),
            assetDefinitionStore: .make(),
            reachability: FakeReachabilityManager(false),
            wallet: .make(),
            eventsDataStore: FakeEventsDataStore(account: .make()))
    }

    init(config: Config,
         analytics: AnalyticsLogger,
         blockchainsProvider: BlockchainsProvider,
         tokensDataStore: TokensDataStore,
         assetDefinitionStore: AssetDefinitionStore,
         reachability: ReachabilityManagerProtocol,
         wallet: Wallet,
         eventsDataStore: NonActivityEventsDataStore) {

        self.eventsDataStore = eventsDataStore
        self.wallet = wallet
        self.reachability = reachability
        self.assetDefinitionStore = assetDefinitionStore
        self.tokensDataStore = tokensDataStore
        self.config = config
        self.analytics = analytics
        self.blockchainsProvider = blockchainsProvider
    }

    public func start() {
        blockchainsProvider
            .blockchains
            .map { [sessionsSubject] blockchains -> ServerDictionary<WalletSession>in
                var sessions: ServerDictionary<WalletSession> = .init()

                for blockchain in blockchains.values {
                    if let session = sessionsSubject.value[safe: blockchain.server] {
                        sessions[blockchain.server] = session
                    } else {
                        sessions[blockchain.server] = self.buildSession(blockchain: blockchain)
                    }
                }
                return sessions
            }.assign(to: \.value, on: sessionsSubject, ownership: .weak)
            .store(in: &cancelable)
    }

    private func buildSession(blockchain: BlockchainProvider) -> WalletSession {
        let ercTokenProvider: TokenProviderType = TokenProvider(
            account: wallet,
            blockchainProvider: blockchain)

        let contractDataFetcher: ContractDataFetcher
        if let value = self.contractDataFetcher[blockchain.server] {
            contractDataFetcher = value
        } else {
            contractDataFetcher = ContractDataFetcher(
                wallet: wallet,
                ercTokenProvider: ercTokenProvider,
                assetDefinitionStore: assetDefinitionStore,
                analytics: analytics,
                reachability: reachability)
        }

        let importToken: ImportToken
        if let value = self.importToken[blockchain.server] {
            importToken = value
        } else {
            importToken = ImportToken(
                tokensDataStore: tokensDataStore,
                contractDataFetcher: contractDataFetcher,
                server: blockchain.server,
                reachability: reachability)
        }
        let nftProvider = FakeNftProvider()
        let tokenAdaptor = TokenAdaptor(assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, wallet: wallet, nftProvider: nftProvider)

        return WalletSession(
            account: wallet,
            server: blockchain.server,
            config: config,
            analytics: analytics,
            ercTokenProvider: ercTokenProvider,
            importToken: importToken,
            blockchainProvider: blockchain,
            nftProvider: FakeNftProvider(),
            tokenAdaptor: tokenAdaptor,
            apiNetworking: FakeApiNetworking())
    }

    public func session(for server: RPCServer) -> WalletSession? {
        sessionsSubject.value[safe: server]
    }
}
