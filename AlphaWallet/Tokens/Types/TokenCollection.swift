//Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Result
import PromiseKit
import Combine
import BigInt

protocol TokenProvidable {
    func token(for contract: AlphaWallet.Address) -> Token?
    func token(for contract: AlphaWallet.Address, server: RPCServer) -> Token?
}

protocol TokenAddable {
    @discardableResult func addCustom(tokens: [ERCToken], shouldUpdateBalance: Bool) -> [Token]
}

protocol TokenCollection: TokenProvidable, TokenAddable {
    var tokens: AnyPublisher<[TokenViewModel], Never> { get }
    //TODO: hide these 2 fields later
    var tokensDataStore: TokensDataStore & DetectedContractsProvideble { get }
    var tokensFilter: TokensFilter { get }

    func mark(token: TokenIdentifiable, isHidden: Bool)
    func token(for contract: AlphaWallet.Address) -> Token?
    func token(for contract: AlphaWallet.Address, server: RPCServer) -> Token?
    func fetch()
    func start()
}

///This contains tokens across multiple-chains
class MultipleChainsTokenCollection: NSObject, TokenCollection {
    
    let tokensFilter: TokensFilter
    private let sessions: ServerDictionary<WalletSession>
    private let config: Config
    private var tokensSubject: CurrentValueSubject<[TokenViewModel], Never> = .init([])

    private let refreshSubject = PassthroughSubject<Void, Never>.init()
    private var cancelable = Set<AnyCancellable>()
    private let coinTickersFetcher: CoinTickersFetcher

    let tokensDataStore: TokensDataStore & DetectedContractsProvideble
    var tokens: AnyPublisher<[TokenViewModel], Never> {
        tokensSubject.eraseToAnyPublisher()
    }
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: NonActivityEventsDataStore

    init(tokensFilter: TokensFilter, tokensDataStore: TokensDataStore & DetectedContractsProvideble, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: NonActivityEventsDataStore, sessions: ServerDictionary<WalletSession>, config: Config, coinTickersFetcher: CoinTickersFetcher) {
        self.tokensFilter = tokensFilter
        self.tokensDataStore = tokensDataStore
        self.coinTickersFetcher = coinTickersFetcher
        self.sessions = sessions
        self.config = config
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
        super.init()
    }

    func start() {
        cancelable.cancellAll()

        let initialOrForceSnapshot = Publishers.Merge(Just<Void>(()), refreshSubject)
            .map { [tokensDataStore, config] _ in tokensDataStore.enabledTokens(for: config.enabledServers) }
            .eraseToAnyPublisher()

        let newOrChanged = tokensDataStore.enabledTokensPublisher(for: config.enabledServers)
            .dropFirst()
            .debounce(for: .seconds(Constants.refreshTokensThresholdSec), scheduler: RunLoop.main)
            .receive(on: RunLoop.main)

        Publishers.Merge(initialOrForceSnapshot, newOrChanged)
            .map { MultipleChainsTokensDataStore.functional.erc20AddressForNativeTokenFilter(servers: self.config.enabledServers, tokens: $0) }
            .map { TokensViewModel.functional.filterAwaySpuriousTokens($0) }
            .map { MultipleChainsTokenCollection.buildViewModels(tokens: $0, sessions: self.sessions, assetDefinitionStore: self.assetDefinitionStore, eventsDataStore: self.eventsDataStore) }
            .sink { [weak self] tokens in
                self?.tokensSubject.send(tokens)
            }.store(in: &cancelable)
    }

    func token(for contract: AlphaWallet.Address) -> Token? {
        tokensDataStore.token(forContract: contract)
    }

    func token(for contract: AlphaWallet.Address, server: RPCServer) -> Token? {
        tokensDataStore.token(forContract: contract, server: server)
    }

    func mark(token: TokenIdentifiable, isHidden: Bool) {
        let primaryKey = TokenObject.generatePrimaryKey(fromContract: token.contractAddress, server: token.server)
        tokensDataStore.updateToken(primaryKey: primaryKey, action: .isHidden(isHidden))
    }

    func fetch() {
        refreshSubject.send(())
    }

    @discardableResult func addCustom(tokens: [ERCToken], shouldUpdateBalance: Bool) -> [Token] {
        tokensDataStore.addCustom(tokens: tokens, shouldUpdateBalance: shouldUpdateBalance)
    }

    private static func buildViewModels(tokens: [Token], sessions: ServerDictionary<WalletSession>, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: NonActivityEventsDataStore) -> [TokenViewModel] {
        return tokens.map { token -> TokenViewModel in
            let viewModel = TokenViewModel(token: token)

            guard let session = sessions[safe: token.server] else { return viewModel }

            let balance = session.tokenBalanceService.tokenBalance(.init(address: token.contractAddress, server: token.server)) ?? viewModel.balance
            let overrides = TokenScriptOverrides(token: token, assetDefinitionStore: assetDefinitionStore, sessions: sessions, eventsDataStore: eventsDataStore)

            return viewModel.override(balance: balance).override(tokenScriptOverrides: overrides)
        }
    }
}
