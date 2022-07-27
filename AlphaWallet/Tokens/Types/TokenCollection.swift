//Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Result
import PromiseKit
import Combine

protocol TokenProvidable {
    func token(for contract: AlphaWallet.Address) -> Token?
    func token(for contract: AlphaWallet.Address, server: RPCServer) -> Token?
}

protocol TokenAddable {
    @discardableResult func addCustom(tokens: [ERCToken], shouldUpdateBalance: Bool) -> [Token]
}

protocol TokenCollection: TokenProvidable, TokenAddable {
    var tokensViewModel: AnyPublisher<TokensViewModel, Never> { get }
    var tokensDataStore: TokensDataStore & DetectedContractsProvideble { get }
    var tokensFilter: TokensFilter { get }

    func fetch()
}

///This contains tokens across multiple-chains
class MultipleChainsTokenCollection: NSObject, TokenCollection {

    let tokensFilter: TokensFilter
    private var tokensViewModelSubject: CurrentValueSubject<TokensViewModel, Never>
    private let refreshSubject = PassthroughSubject<Void, Never>.init()
    private var cancelable = Set<AnyCancellable>()
    private let coinTickersFetcher: CoinTickersFetcher

    let tokensDataStore: TokensDataStore & DetectedContractsProvideble
    var tokensViewModel: AnyPublisher<TokensViewModel, Never> {
        tokensViewModelSubject.eraseToAnyPublisher()
    }

    init(tokensFilter: TokensFilter, tokensDataStore: TokensDataStore & DetectedContractsProvideble, config: Config, coinTickersFetcher: CoinTickersFetcher) {
        self.tokensFilter = tokensFilter
        self.tokensDataStore = tokensDataStore
        self.coinTickersFetcher = coinTickersFetcher

        let enabledServers = config.enabledServers
        let tokens = tokensDataStore.enabledTokens(for: enabledServers)
        self.tokensViewModelSubject = .init(.init(tokensFilter: tokensFilter, tokens: tokens, config: config))
        super.init()

        tokensDataStore
            .enabledTokensPublisher(for: enabledServers)
            .receive(on: Config.backgroundQueue)
            .combineLatest(refreshSubject, coinTickersFetcher.tickersDidUpdate, { tokens, _, _ in tokens })
            .map { MultipleChainsTokensDataStore.functional.erc20AddressForNativeTokenFilter(servers: enabledServers, tokens: $0) }
            .map { TokensViewModel.functional.filterAwaySpuriousTokens($0) }
            .map { TokensViewModel(tokensFilter: tokensFilter, tokens: $0, config: config) }
            .debounce(for: .seconds(Constants.refreshTokensThresholdSec), scheduler: Config.backgroundQueue)
            .receive(on: RunLoop.main)
            .sink { [weak self] tokensViewModel in
                self?.tokensViewModelSubject.send(tokensViewModel)
            }.store(in: &cancelable)
    }

    func fetch() {
        refreshSubject.send(())
    }

    func token(for contract: AlphaWallet.Address) -> Token? {
        tokensDataStore.token(forContract: contract)
    }

    func token(for contract: AlphaWallet.Address, server: RPCServer) -> Token? {
        tokensDataStore.token(forContract: contract, server: server)
    }

    @discardableResult func addCustom(tokens: [ERCToken], shouldUpdateBalance: Bool) -> [Token] {
        tokensDataStore.addCustom(tokens: tokens, shouldUpdateBalance: shouldUpdateBalance)
    }
}
