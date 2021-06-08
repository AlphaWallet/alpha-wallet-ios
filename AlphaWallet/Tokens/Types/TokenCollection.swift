//Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Result

///This contains tokens across multiple-chains
class TokenCollection {
    private var subscribers: [(Result<TokensViewModel, TokenError>) -> Void] = []
    private var rateLimitedUpdater: RateLimiter?
    private let filterTokensCoordinator: FilterTokensCoordinator

    let tokenDataStores: [TokensDataStore]

    init(filterTokensCoordinator: FilterTokensCoordinator, tokenDataStores: [TokensDataStore]) {
        self.filterTokensCoordinator = filterTokensCoordinator
        self.tokenDataStores = tokenDataStores
        for each in tokenDataStores {
            each.delegate = self
        }
    }

    func fetch() {
        for each in tokenDataStores {
            each.fetch()
        }
    }

    func subscribe(_ subscribe: @escaping (_ result: Result<TokensViewModel, TokenError>) -> Void) {
        subscribers.append(subscribe)
    }
}

extension TokenCollection: TokensDataStoreDelegate {
    
    func didUpdate(in dataStore: TokensDataStore, refreshImmediately: Bool) {
        if refreshImmediately {
            notifySubscribersOfUpdatedTokens()
            return
        }

        //The first time, we notify the subscribers and hence load the data in the UI immediately, otherwise the list of tokens in the Wallet tab will be empty for a few seconds after launch
        if rateLimitedUpdater == nil {
            rateLimitedUpdater = RateLimiter(limit: 2) { [weak self] in
                self?.notifySubscribersOfUpdatedTokens()
            }
            notifySubscribersOfUpdatedTokens()
        } else {
            rateLimitedUpdater?.run()
        }
    }

    private func notifySubscribersOfUpdatedTokens() {
        //TODO not efficient. But how many elements can we actually have. Not that many?
        var tickers: [AddressAndRPCServer: CoinTicker] = [:]
        var tokens: [TokenObject] = []

        //This might slow things down. Especially if it runs too many times unnecessarily
        for each in tokenDataStores {
            for (key, value) in each.tickers {
                tickers[key] = value
            }

            tokens.append(contentsOf: each.enabledObject)
        }
        
        let tokensViewModel = TokensViewModel(filterTokensCoordinator: filterTokensCoordinator, tokens: tokens, tickers: tickers)
        for each in subscribers {
            each(.success(tokensViewModel))
        }
    }
}

extension RPCServer {
    var displayOrderPriority: Int {
        switch self {
        case .main: return 1
        case .xDai: return 2
        case .classic: return 3
        case .poa: return 4
        case .ropsten: return 5
        case .kovan: return 6
        case .rinkeby: return 7
        case .sokol: return 8
        case .callisto: return 9
        case .goerli: return 10
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
        }
    }
}
