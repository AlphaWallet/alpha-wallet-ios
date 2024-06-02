//
//  AlphaWalletTokensService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.07.2022.
//

import Combine
import Foundation

import AlphaWalletWeb3

import CombineExt

public class AlphaWalletTokensService: TokensService {
    private var cancelable = Set<AnyCancellable>()
    private let providers: CurrentValueSubject<ServerDictionary<TokenSourceProvider>, Never> = .init(.init())
    private let sessionsProvider: SessionsProvider
    private let analytics: AnalyticsLogger
    private let tokensDataStore: TokensDataStore
    private let transactionsStorage: TransactionDataStore
    private let assetDefinitionStore: AssetDefinitionStore
    private let transporter: ApiTransporter
    private let fetchTokenScriptFiles: FetchTokenScriptFiles
    private lazy var tokenRepairService = TokenRepairService(tokensDataStore: tokensDataStore, sessionsProvider: sessionsProvider)

    public var tokens: [Token] {
        get async {
            let tokenProviders: ServerDictionary<TokenSourceProvider> = providers.value
            let all: [Token] = await tokenProviders.asyncFlatMap { await $0.value.getTokens() }
            return AlphaWalletTokensService.filterAwaySpuriousTokens(all)
        }
    }

    public lazy var tokensPublisher: AnyPublisher<[Token], Never> = {
        providers.map { $0.values }
            .flatMapLatest { $0.map { $0.tokensPublisher }.combineLatest() }
            .map { $0.flatMap { $0 } }
            .map { [providers] tokens -> [Token] in
                let servers = Array(providers.value.keys)
                return MultipleChainsTokensDataStore.functional.erc20AddressForNativeTokenFilter(servers: servers, tokens: tokens)
            }.map { AlphaWalletTokensService.filterAwaySpuriousTokens($0) }
            .eraseToAnyPublisher()
    }()

    public func tokensChangesetPublisher(servers: [RPCServer]) -> AnyPublisher<ChangeSet<[Token]>, Never> {
        tokensDataStore.tokensChangesetPublisher(for: servers, predicate: nil)
    }

    public lazy var addedTokensPublisher: AnyPublisher<[Token], Never> = {
        providers.map { $0.values }
            .flatMapLatest { $0.map { $0.addedTokensPublisher }.merge() }
            .eraseToAnyPublisher()
    }()

    /// Fires each time we recreate token source, e.g when servers are chenging
    public lazy var providersHasChanged: AnyPublisher<Void, Never> = {
        providers.filter { !$0.isEmpty }
            .mapToVoid()
            .eraseToAnyPublisher()
    }()

    public init(sessionsProvider: SessionsProvider, tokensDataStore: TokensDataStore, analytics: AnalyticsLogger, transactionsStorage: TransactionDataStore, assetDefinitionStore: AssetDefinitionStore, fetchTokenScriptFiles: FetchTokenScriptFiles, transporter: ApiTransporter) {
        self.transporter = transporter
        self.sessionsProvider = sessionsProvider
        self.tokensDataStore = tokensDataStore
        self.analytics = analytics
        self.transactionsStorage = transactionsStorage
        self.assetDefinitionStore = assetDefinitionStore
        self.fetchTokenScriptFiles = fetchTokenScriptFiles
    }

    public func tokens(for servers: [RPCServer]) async -> [Token] {
        return await tokensDataStore.tokens(for: servers)
    }

    public func mark(token: TokenIdentifiable, isHidden: Bool) {
        let primaryKey = TokenObject.generatePrimaryKey(fromContract: token.contractAddress, server: token.server)
        Task {
            await tokensDataStore.updateToken(primaryKey: primaryKey, action: .isHidden(isHidden))
            assetDefinitionStore.deleteXmlFileDownloadedFromOfficialRepo(forContract: token.contractAddress)
        }
    }

    public func token(for contract: AlphaWallet.Address) async -> Token? {
        return await tokensDataStore.token(for: contract)
    }

    public func token(for contract: AlphaWallet.Address, server: RPCServer) async -> Token? {
        return await tokensDataStore.token(for: contract, server: server)
    }

    public func refresh() {
        let adapters = providers.value.map { $0.value }
        adapters.forEach { $0.refresh() }
    }

    public func stop() {
        //NOTE: TokenBalanceFetcher has strong ref to Tokens Service, so we need to remove fetchers manually
        providers.value = .init()
    }

    public func start() {
        sessionsProvider.sessions
            .map { [weak self] sessions in
                var providers: ServerDictionary<TokenSourceProvider> = .init()
                for session in sessions {
                    if let provider = self?.providers.value[safe: session.key] {
                        providers[session.key] = provider
                    } else {
                        guard let provider = self?.buildTokenSource(session: session.value) else { continue }
                        provider.start()

                        providers[session.key] = provider
                    }
                }

                return providers
            }.assign(to: \.value, on: providers, ownership: .weak)
            .store(in: &cancelable)

        fetchTokenScriptFiles.start()
        //tokenRepairService.start()
    }

    private func buildTokenSource(session: WalletSession) -> TokenSourceProvider {
        let balanceFetcher = TokenBalanceFetcher(
            session: session,
            tokensDataStore: tokensDataStore,
            etherToken: MultipleChainsTokensDataStore.functional.etherToken(forServer: session.server),
            assetDefinitionStore: assetDefinitionStore,
            analytics: analytics,
            transporter: transporter)

        balanceFetcher.erc721TokenIdsFetcher = transactionsStorage

        return ClientSideTokenSourceProvider(
            session: session,
            tokensDataStore: tokensDataStore,
            balanceFetcher: balanceFetcher)
    }

    deinit {
        stop()
    }

    public func addOrUpdate(with actions: [AddOrUpdateTokenAction]) async -> [Token] {
        await tokensDataStore.addOrUpdate(with: actions)
    }

    public func updateToken(primaryKey: String, action: TokenFieldUpdate) async -> Bool? {
        await tokensDataStore.updateToken(primaryKey: primaryKey, action: action)
    }

    public func refreshBalance(updatePolicy: TokenBalanceFetcher.RefreshBalancePolicy) {
        switch updatePolicy {
        case .token(let token):
            guard let provider = providers.value[safe: token.server] else { return }
            provider.refreshBalance(for: [token])
        case .all:
            for provider in providers.value.values {
                if Config().development.shouldDisableRefreshAllTokensBalance {
                    return
                }
                Task { @MainActor in
                    let tokens = await provider.getTokens()
                    provider.refreshBalance(for: tokens)
                }
            }
        case .tokens(let tokens):
            if Config().development.shouldDisableRefreshTokensBalance {
                return
            }
            for token in tokens {
                guard let provider = providers.value[safe: token.server] else { return }
                provider.refreshBalance(for: [token])
            }
        case .eth:
            for (server, provider) in providers.value {
                let etherToken = MultipleChainsTokensDataStore.functional.etherToken(forServer: server)
                provider.refreshBalance(for: [etherToken])
            }
        }
    }

    public func tokenPublisher(for contract: AlphaWallet.Address, server: RPCServer) -> AnyPublisher<Token?, Never> {
        tokensDataStore.tokenPublisher(for: contract, server: server)
            .replaceError(with: nil)
            .eraseToAnyPublisher()
    }

    public func update(token: TokenIdentifiable, value: TokenFieldUpdate) {
        let primaryKey = TokenObject.generatePrimaryKey(fromContract: token.contractAddress, server: token.server)
        Task {
            await tokensDataStore.updateToken(primaryKey: primaryKey, action: value)
        }
    }

    //Remove tokens that look unwanted in the Wallet tab
    public static func filterAwaySpuriousTokens<T>(_ tokens: [T]) -> [T] where T: TokenFilterable {
        return tokens.filter {
            switch $0.type {
            case .nativeCryptocurrency, .erc20, .erc875, .erc721, .erc721ForTickets:
                return !($0.name.isEmpty && $0.symbol.isEmpty && $0.decimals == 0)
            case .erc1155:
                return true
            }
        }
    }
}

extension AlphaWalletTokensService {
    public func setBalanceTestsOnly(balance: Balance, for token: Token) -> Task<Bool?, Never> {
        return Task {
            await tokensDataStore.updateToken(addressAndRpcServer: token.addressAndRPCServer, action: .value(balance.value))
        }
    }

    public func setNftBalanceTestsOnly(_ value: NonFungibleBalance, for token: Token) -> Task<Bool?, Never> {
        return Task {
            await tokensDataStore.updateToken(addressAndRpcServer: token.addressAndRPCServer, action: .nonFungibleBalance(value))
        }
    }

    public func addOrUpdateTokenTestsOnly(token: Token) -> Task<[Token], Never> {
        return Task {
            await tokensDataStore.addOrUpdate(with: [.init(token)])
        }
    }

    public func deleteTokenTestsOnly(token: Token) {
        tokensDataStore.deleteTestsOnly(tokens: [token])
    }
}

extension AlphaWalletTokensService {
    public func alreadyAddedContracts(for server: RPCServer) async -> [AlphaWallet.Address] {
        await tokensDataStore.tokens(for: [server]).map { $0.contractAddress }
    }

    public func deletedContracts(for server: RPCServer) async -> [AlphaWallet.Address] {
        await tokensDataStore.deletedContracts(forServer: server).map { $0.address }
    }

    public func hiddenContracts(for server: RPCServer) async -> [AlphaWallet.Address] {
        await tokensDataStore.hiddenContracts(forServer: server).map { $0.address }
    }

    public func delegateContracts(for server: RPCServer) async -> [AlphaWallet.Address] {
        await tokensDataStore.delegateContracts(forServer: server).map { $0.address }
    }
}
