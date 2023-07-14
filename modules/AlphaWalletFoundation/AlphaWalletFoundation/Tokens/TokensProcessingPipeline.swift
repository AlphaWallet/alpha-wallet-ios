//
//  TokensProcessingPipeline.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.07.2022.
//

import Foundation
import Combine
import CombineExt

public protocol TokensProcessingPipeline {
    var tokenViewModels: AnyPublisher<[TokenViewModel], Never> { get }

    func tokenHolders(for token: TokenIdentifiable) -> [TokenHolder]
    func tokenHoldersPublisher(for token: TokenIdentifiable) -> AnyPublisher<[TokenHolder], Never>
    func tokenHolderPublisher(for token: TokenIdentifiable, tokenId: TokenId) -> AnyPublisher<TokenHolder?, Never>
    func tokenViewModelPublisher(for contract: AlphaWallet.Address, server: RPCServer) -> AnyPublisher<TokenViewModel?, Never>
    func tokenViewModel(for contract: AlphaWallet.Address, server: RPCServer) -> TokenViewModel?
    func start()
}

public final class WalletDataProcessingPipeline: TokensProcessingPipeline {
    private let coinTickersFetcher: CoinTickersFetcher
    private let coinTickersProvider: CoinTickersProvider
    private let tokensService: TokensService
    private let assetDefinitionStore: AssetDefinitionStore
    private var cancelable = Set<AnyCancellable>()
    private let eventsDataStore: NonActivityEventsDataStore
    private let wallet: Wallet
    private let queue = DispatchQueue(label: "org.alphawallet.swift.walletData.processingPipeline", qos: .userInitiated)
    private let currencyService: CurrencyService
    private let sessionsProvider: SessionsProvider

    public lazy var tokenViewModels: AnyPublisher<[TokenViewModel], Never> = {
        let whenTickersChanged = coinTickersProvider.tickersDidUpdate.dropFirst()
            .receive(on: queue)
            .map { [tokensService] _ in tokensService.tokens }

        let whenCurrencyChanged = currencyService.$currency.dropFirst()
            .receive(on: queue)
            .map { [tokensService] _ in tokensService.tokens }

        let whenSignatureOrBodyChanged = assetDefinitionStore.assetsSignatureOrBodyChange
            .receive(on: queue)
            .map { [tokensService] _ in tokensService.tokens }

        let whenTokensHasChanged = tokensService.tokensPublisher
            .dropFirst()
            .receive(on: queue)

        let whenCollectionHasChanged = Publishers.Merge4(whenTokensHasChanged, whenTickersChanged, whenSignatureOrBodyChanged, whenCurrencyChanged)
            .map { $0.map { TokenViewModel(token: $0) } }
            .flatMapLatest { [weak self] in self?.applyTickers(tokens: $0) ?? .empty() }
            .flatMapLatest { [weak self] in self?.applyTokenScriptOverrides(tokens: $0) ?? .empty() }
            .receive(on: RunLoop.main)

        let initialSnapshot = Just(tokensService.tokens)
            .map { $0.map { TokenViewModel(token: $0) } }
            .flatMapLatest { [weak self] in self?.applyTickers(tokens: $0) ?? .empty() }
            .flatMapLatest { [weak self] in self?.applyTokenScriptOverrides(tokens: $0) ?? .empty() }

        return Publishers.Merge(whenCollectionHasChanged, initialSnapshot)
            .share(replay: 1)
            .eraseToAnyPublisher()
    }()

    public init(wallet: Wallet,
                tokensService: TokensService,
                coinTickersFetcher: CoinTickersFetcher,
                coinTickersProvider: CoinTickersProvider,
                assetDefinitionStore: AssetDefinitionStore,
                eventsDataStore: NonActivityEventsDataStore,
                currencyService: CurrencyService,
                sessionsProvider: SessionsProvider) {

        self.sessionsProvider = sessionsProvider
        self.wallet = wallet
        self.currencyService = currencyService
        self.eventsDataStore = eventsDataStore
        self.tokensService = tokensService
        self.coinTickersFetcher = coinTickersFetcher
        self.coinTickersProvider = coinTickersProvider
        self.assetDefinitionStore = assetDefinitionStore
    }

    public func start() {
        tokensService.start()
        startTickersHandling()
    }

    deinit {
        tokensService.stop()
    }

    public func tokenHolderPublisher(for token: TokenIdentifiable, tokenId: TokenId) -> AnyPublisher<TokenHolder?, Never> {
        tokenHoldersPublisher(for: token)
            .map { tokenHolders in
                switch token.type {
                case .erc721, .erc875, .erc721ForTickets:
                    return tokenHolders.first { $0.tokens[0].id == tokenId }
                case .erc1155:
                    return tokenHolders.first(where: { $0.tokens.contains(where: { $0.id == tokenId }) })
                case .nativeCryptocurrency, .erc20:
                    return nil
                }
            }.eraseToAnyPublisher()
    }

    public func tokenViewModel(for contract: AlphaWallet.Address, server: RPCServer) -> TokenViewModel? {
        return tokensService.token(for: contract, server: server)
            .flatMap { TokenViewModel(token: $0) }
            .flatMap { [weak self] in self?.applyTicker(token: $0) }
            .flatMap { [weak self] in self?.applyTokenScriptOverrides(token: $0) }
    }

    public func tokenViewModelPublisher(for contract: AlphaWallet.Address, server: RPCServer) -> AnyPublisher<TokenViewModel?, Never> {
        let whenTickersHasChanged: AnyPublisher<Token?, Never> = coinTickersProvider.tickersDidUpdate.dropFirst()
            //NOTE: filter coin ticker events, allow only if ticker has change
            .compactMap { [coinTickersProvider, currencyService] _ in coinTickersProvider.ticker(for: .init(address: contract, server: server), currency: currencyService.currency) }
            .removeDuplicates()
            .map { [tokensService] _ in tokensService.token(for: contract, server: server) }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()

        let whenSignatureOrBodyChanged: AnyPublisher<Token?, Never> = assetDefinitionStore
            .assetsSignatureOrBodyChange(for: contract)
            .map { [tokensService] _ in tokensService.token(for: contract, server: server) }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()

        let whenEventHasChanged: AnyPublisher<Token?, Never> = eventsDataStore
            .recentEventsChangeset(for: contract)
            .filter({ changeset in
                switch changeset {
                case .update(let events, _, let insertions, let modifications):
                    return !insertions.map { events[$0] }.isEmpty || !modifications.map { events[$0] }.isEmpty
                case .initial, .error:
                    return false
                }
            }).map { [tokensService] _ in tokensService.token(for: contract, server: server) }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()

        return Publishers.Merge4(tokensService.tokenPublisher(for: contract, server: server), whenTickersHasChanged, whenSignatureOrBodyChanged, whenEventHasChanged)
            .map { $0.flatMap { TokenViewModel(token: $0) } }
            .map { [weak self] in self?.applyTicker(token: $0) }
            .map { [weak self] in self?.applyTokenScriptOverrides(token: $0) }
            .eraseToAnyPublisher()
    }

    public func tokenHolders(for token: TokenIdentifiable) -> [TokenHolder] {
        guard let session = sessionsProvider.session(for: token.server) else { return [] }
        let tokenAdaptor = session.tokenAdaptor
        return tokenViewModel(for: token.contractAddress, server: token.server).flatMap { tokenAdaptor.getTokenHolders(token: $0) } ?? []
    }

    public func tokenHoldersPublisher(for token: TokenIdentifiable) -> AnyPublisher<[TokenHolder], Never> {
        guard let session = sessionsProvider.session(for: token.server) else { return .empty() }
        let tokenAdaptor = session.tokenAdaptor
        return tokenViewModelPublisher(for: token.contractAddress, server: token.server)
            .compactMap { $0 }
            .map { tokenAdaptor.getTokenHolders(token: $0) }
            .eraseToAnyPublisher()
    }

    private func startTickersHandling() {
        //NOTE: To don't block start method, and apply delay to fetch tickers, inital only
        let tokens = Publishers.Merge(Just(tokensService.tokens).delay(for: .seconds(2), scheduler: queue), tokensService.addedTokensPublisher)
            .removeDuplicates()

        Publishers.CombineLatest(tokens, currencyService.$currency)
            .sink { [coinTickersFetcher, tokensService] tokens, currency in
                let nativeCryptoForAllChains = RPCServer.allCases.map { MultipleChainsTokensDataStore.functional.etherToken(forServer: $0) }
                //NOTE: remove type type filtering when add support for nonfungibles
                let tokens = (tokens + nativeCryptoForAllChains).filter { !$0.server.isTestnet && ($0.type == .nativeCryptocurrency || $0.type == .erc20 ) }
                let uniqueTokens = Set(tokens).map {
                    TokenMappedToTicker(
                        symbol: $0.symbol,
                        name: $0.name,
                        contractAddress: $0.contractAddress,
                        server: $0.server,
                        coinGeckoId: $0.info.coinGeckoId)
                }

                coinTickersFetcher.fetchTickers(for: uniqueTokens, force: false, currency: currency)
                tokensService.refreshBalance(updatePolicy: .tokens(tokens: tokens))
            }.store(in: &cancelable)

        coinTickersProvider.updateTickerIds
            .map { [tokensService] data -> [AddOrUpdateTokenAction] in
                let v = data.compactMap { i in tokensService.token(for: i.key.address, server: i.key.server).flatMap { ($0, i.tickerId) } }
                return v.map { AddOrUpdateTokenAction.update(token: $0.0, field: .coinGeckoTickerId($0.1)) }
            }.sink { [tokensService] actions in
                tokensService.addOrUpdate(with: actions)
            }.store(in: &cancelable)
    }

    private func applyTokenScriptOverrides(tokens: [TokenViewModel]) -> AnyPublisher<[TokenViewModel], Never> {
        let overrides = tokens.map { token -> TokenViewModel in
            guard let session = sessionsProvider.session(for: token.server) else { return token }
            let overrides = session.tokenAdaptor.tokenScriptOverrides(token: token)

            return token.override(tokenScriptOverrides: overrides)
        }
        return .just(overrides)
    }

    private func applyTokenScriptOverrides(token: TokenViewModel?) -> TokenViewModel? {
        guard let token = token else { return token }
        guard let session = sessionsProvider.session(for: token.server) else { return token }
        let overrides = session.tokenAdaptor.tokenScriptOverrides(token: token)
        return token.override(tokenScriptOverrides: overrides)
    }

    private func applyTickers(tokens: [TokenViewModel]) -> AnyPublisher<[TokenViewModel], Never> {
        return .just(tokens.compactMap { applyTicker(token: $0) })
    }

    private func applyTicker(token: TokenViewModel?) -> TokenViewModel? {
        guard let token = token else { return nil }
        let ticker = coinTickersProvider.ticker(for: .init(address: token.contractAddress, server: token.server), currency: currencyService.currency)
        let balance: BalanceViewModel
        switch token.type {
        case .nativeCryptocurrency:
            balance = .init(balance: NativecryptoBalanceViewModel(balance: token, ticker: ticker))
        case .erc20:
            balance = .init(balance: Erc20BalanceViewModel(balance: token, ticker: ticker))
        case .erc875, .erc721, .erc721ForTickets, .erc1155:
            balance = .init(balance: NFTBalanceViewModel(balance: token, ticker: ticker))
        }

        return token.override(balance: balance)
    }
}

public extension TokensProcessingPipeline {

    func tokenViewModelPublisher(for token: Token) -> AnyPublisher<TokenViewModel?, Never> {
        return tokenViewModelPublisher(for: token.contractAddress, server: token.server)
    }

    func tokenViewModel(for token: Token) -> TokenViewModel? {
        return tokenViewModel(for: token.contractAddress, server: token.server)
    }
}
