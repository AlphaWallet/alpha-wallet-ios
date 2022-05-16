//Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Result
import PromiseKit
import Combine

protocol TokenCollection {
    var tokensViewModel: AnyPublisher<TokensViewModel, Never> { get }
    var tokensDataStore: TokensDataStore { get }

    func fetch()
}

///This contains tokens across multiple-chains
final class MultipleChainsTokenCollection: NSObject, TokenCollection {
    private let tokensFilter: TokensFilter
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
        let tokenObjects = tokensDataStore.enabledTokenObjects(forServers: enabledServers)
        self.tokensViewModelSubject = .init(.init(tokensFilter: tokensFilter, tokens: tokenObjects, config: config))
        super.init()

        tokensDataStore
            .enabledTokenObjectsChangesetPublisher(forServers: enabledServers)
            .receive(on: queue)
            .combineLatest(refereshSubject, { changeset, _ in return changeset.asTokensArray })
            .map { MultipleChainsTokensDataStore.functional.erc20AddressForNativeTokenFilter(servers: enabledServers, tokenObjects: $0) }
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

extension RPCServer {
    var displayOrderPriority: Int {
        switch self {
        case .main: return 1
        case .candle: return 2
        case .xDai: return 3
        case .classic: return 4
        case .poa: return 5
        case .ropsten: return 6
        case .kovan: return 7
        case .rinkeby: return 8
        case .sokol: return 9
        case .callisto: return 10
        case .goerli: return 11
        case .artis_sigma1: return 246529
        case .artis_tau1: return 246785
        case .binance_smart_chain: return 12
        case .binance_smart_chain_testnet: return 13
        case .custom(let custom): return 300000 + custom.chainID
        case .heco: return 14
        case .heco_testnet: return 15
        case .fantom: return 16
        case .fantom_testnet: return 17
        case .avalanche: return 18
        case .avalanche_testnet: return 19
        case .polygon: return 20
        case .mumbai_testnet: return 21
        case .optimistic: return 22
        case .optimisticKovan: return 23
        case .cronosTestnet: return 24
        case .arbitrum: return 25
        case .arbitrumRinkeby: return 26
        case .palm: return 27
        case .palmTestnet: return 28
        case .klaytnCypress: return 29
        case .klaytnBaobabTestnet: return 30 
        }
    }
}
