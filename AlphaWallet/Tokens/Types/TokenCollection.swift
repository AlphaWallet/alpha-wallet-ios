//Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Result
import PromiseKit
import Combine

protocol TokenCollection {
    var tokensViewModel: AnyPublisher<TokensViewModel, Never> { get }
    var tokensDataStore: TokensDataStore { get }
    var tokensFilter: TokensFilter { get }

    func fetch()
}

///This contains tokens across multiple-chains
class MultipleChainsTokenCollection: NSObject, TokenCollection {
    let tokensFilter: TokensFilter
    private var tokensViewModelSubject: CurrentValueSubject<TokensViewModel, Never>

    private let refereshSubject = PassthroughSubject<Void, Never>.init()
    private var cancelable = Set<AnyCancellable>()

    let tokensDataStore: TokensDataStore
    var tokensViewModel: AnyPublisher<TokensViewModel, Never> {
        tokensViewModelSubject.eraseToAnyPublisher()
    }
    private let queue = DispatchQueue(label: "com.MultipleChainsTokenCollection.updateQueue")

    init(tokensFilter: TokensFilter, tokensDataStore: TokensDataStore, config: Config) {
        self.tokensFilter = tokensFilter
        self.tokensDataStore = tokensDataStore

        let enabledServers = config.enabledServers
        let tokens = tokensDataStore.enabledTokens(for: enabledServers)
        self.tokensViewModelSubject = .init(.init(tokensFilter: tokensFilter, tokens: tokens, config: config))
        super.init()

        tokensDataStore
            .enabledTokensPublisher(for: enabledServers)
            .receive(on: queue)
            .combineLatest(refereshSubject, { tokens, _ in tokens })
            .map { MultipleChainsTokensDataStore.functional.erc20AddressForNativeTokenFilter(servers: enabledServers, tokens: $0) }
            .map { TokensViewModel.functional.filterAwaySpuriousTokens($0) }
            .map { TokensViewModel(tokensFilter: tokensFilter, tokens: $0, config: config) }
            .debounce(for: .seconds(Constants.refreshTokensThresholdSec), scheduler: queue)
            .receive(on: RunLoop.main)
            .sink { [weak self] tokensViewModel in
                self?.tokensViewModelSubject.send(tokensViewModel)
            }.store(in: &cancelable)
    }

    func fetch() {
        refereshSubject.send(())
    }
}
