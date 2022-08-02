//
//  AlphaWalletTokensService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.07.2022.
//

import Foundation
import Combine
import CombineExt

class AlphaWalletTokensService: TokensService {
    //FIXME: remove it later
    private static let tokenUpdateBalanceQueue = DispatchQueue(label: "org.alphawallet.swift.tokenBalanceFetcher")
    private var cancelable = Set<AnyCancellable>()
    private var tokensChangedSubject: PassthroughSubject<Void, Never> = .init()
    private let providers: CurrentValueSubject<ServerDictionary<TokenSourceProvider>, Never> = .init(.init())
    private let autoDetectTransactedTokensQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Auto-detect Transacted Tokens"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private let autoDetectTokensQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Auto-detect Tokens"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private let sessionsProvider: SessionsProvider
    private let analytics: AnalyticsLogger
    private let importToken: ImportToken
    private let tokensDataStore: TokensDataStore
    private let transactionsStorage: TransactionDataStore
    private let nftProvider: NFTProvider
    private let assetDefinitionStore: AssetDefinitionStore

    var objectWillChange: AnyPublisher<Void, Never> {
        tokensChangedSubject.eraseToAnyPublisher()
    }
    private (set) var tokens: [Token] = []

    var newTokens: AnyPublisher<[Token], Never> {
        providers.map { $0.values }
            .flatMapLatest { $0.map { $0.newTokens }.merge() }
            .eraseToAnyPublisher()
    }

    init(sessionsProvider: SessionsProvider, tokensDataStore: TokensDataStore, analytics: AnalyticsLogger, importToken: ImportToken, transactionsStorage: TransactionDataStore, nftProvider: NFTProvider, assetDefinitionStore: AssetDefinitionStore) {
        self.sessionsProvider = sessionsProvider
        self.tokensDataStore = tokensDataStore
        self.importToken = importToken
        self.analytics = analytics
        self.transactionsStorage = transactionsStorage
        self.nftProvider = nftProvider
        self.assetDefinitionStore = assetDefinitionStore
    }

    func tokens(for servers: [RPCServer]) -> [Token] {
        return tokensDataStore.enabledTokens(for: servers)
    }

    func mark(token: TokenIdentifiable, isHidden: Bool) {
        let primaryKey = TokenObject.generatePrimaryKey(fromContract: token.contractAddress, server: token.server)
        tokensDataStore.updateToken(primaryKey: primaryKey, action: .isHidden(isHidden))
    }

    func token(for contract: AlphaWallet.Address) -> Token? {
        //NOTE: same as below
        return tokensDataStore.token(forContract: contract)
    }

    func token(for contract: AlphaWallet.Address, server: RPCServer) -> Token? {
        //NOTE: do we need to get it from datastore and not from adapter?
        return tokensDataStore.token(forContract: contract, server: server)
    }

    func refresh() {
        let adapters = providers.value.map { $0.value }
        adapters.forEach { $0.refresh() }
    }

    func stop() {
        //NOTE: TokenBalanceFetcher has strong ref to Tokens Service, so we need to remove fetchers manually
        providers.value = .init()
        autoDetectTransactedTokensQueue.cancelAllOperations()
        autoDetectTokensQueue.cancelAllOperations()
    }

    func start() {
        sessionsProvider.sessions.map { [weak self] sessions in
            var providers: ServerDictionary<TokenSourceProvider> = .init()
            for session in sessions {
                if let provider = self?.providers.value[safe: session.key] {
                    providers[session.key] = provider
                } else {
                    guard let provider = self?.makeTokenSource(session: session.value) else { continue }
                    provider.start()

                    providers[session.key] = provider
                }
            }

            return providers
        }.assign(to: \.value, on: providers, ownership: .weak)
        .store(in: &cancelable)

        providers.map { $0.values }
            .flatMapLatest { $0.map { $0.tokensPublisher }.combineLatest() }
            .map { $0.flatMap { $0 } }
            .map { [providers] in MultipleChainsTokensDataStore.functional.erc20AddressForNativeTokenFilter(servers: Array(providers.value.keys), tokens: $0) }
            .map { TokensViewModel.functional.filterAwaySpuriousTokens($0) }
            //.removeDuplicates() //FIXME: Maybe it needs to handle duplicates here, but what the logic is? do we need to compare all fields for object?
            .sink(receiveValue: { [weak self] tokens in
                self?.tokens = tokens
                self?.tokensChangedSubject.send(())
            }).store(in: &cancelable)
    }

    private func makeTokenSource(session: WalletSession) -> TokenSourceProvider {
        let etherToken = MultipleChainsTokensDataStore.functional.etherToken(forServer: session.server)
        let balanceFetcher = TokenBalanceFetcher(session: session, nftProvider: nftProvider, service: self, etherToken: etherToken, assetDefinitionStore: assetDefinitionStore, analytics: analytics, queue: AlphaWalletTokensService.tokenUpdateBalanceQueue)
        balanceFetcher.erc721TokenIdsFetcher = transactionsStorage
        
        return ClientSideTokenSourceProvider(session: session, autoDetectTransactedTokensQueue: autoDetectTransactedTokensQueue, autoDetectTokensQueue: autoDetectTokensQueue, importToken: importToken, tokensDataStore: tokensDataStore, balanceFetcher: balanceFetcher)
    }

    deinit {
        stop()
    }

    func addCustom(tokens: [ERCToken], shouldUpdateBalance: Bool) -> [Token] {
        tokensDataStore.addCustom(tokens: tokens, shouldUpdateBalance: shouldUpdateBalance)
    }

    func refreshBalance(updatePolicy: TokenBalanceFetcher.RefreshBalancePolicy) {
        switch updatePolicy {
        case .token(let token):
            guard let provider = providers.value[safe: token.server] else { return }
            provider.refreshBalance(for: [token])
        case .all:
            for provider in providers.value.values {
                provider.refreshBalance(for: provider.tokens)
            }
        case .tokens(let tokens):
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

    func tokenPublisher(for contract: AlphaWallet.Address, server: RPCServer) -> AnyPublisher<Token?, Never> {
        guard let provider = providers.value[safe: server] else { return .empty() }
        return provider.tokenPublisher(for: contract)
    }

    func update(token: TokenIdentifiable, value: TokenUpdateAction) {
        let primaryKey = TokenObject.generatePrimaryKey(fromContract: token.contractAddress, server: token.server)
        tokensDataStore.updateToken(primaryKey: primaryKey, action: value)
    }
}

extension AlphaWalletTokensService: TokensServiceTests {
    func setBalanceTestsOnly(balance: Balance, for token: Token) {
        tokensDataStore.updateToken(addressAndRpcServer: token.addressAndRPCServer, action: .value(balance.value))
    }

    func setNftBalanceTestsOnly(_ value: NonFungibleBalance, for token: Token) {
        tokensDataStore.updateToken(addressAndRpcServer: token.addressAndRPCServer, action: .nonFungibleBalance(value))
    }

    func addOrUpdateTokenTestsOnly(token: Token) {
        tokensDataStore.addOrUpdate(tokensOrContracts: [.token(token)])
    }

    func deleteTokenTestsOnly(token: Token) {
        tokensDataStore.deleteTestsOnly(tokens: [token])
    } 
}
