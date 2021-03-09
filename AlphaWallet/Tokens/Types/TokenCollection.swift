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
    func didUpdate(result: Result<TokensViewModel, TokenError>, refreshImmediately: Bool = false) {
        if refreshImmediately {
            DispatchQueue.main.async {
                self.notifySubscribersOfUpdatedTokens()
            }

            return
        }

        //The first time, we notify the subscribers and hence load the data in the UI immediately, otherwise the list of tokens in the Wallet tab will be empty for a few seconds after launch
        if rateLimitedUpdater == nil {
            rateLimitedUpdater = RateLimiter(limit: 2) { [weak self] in
                DispatchQueue.main.async {
                    self?.notifySubscribersOfUpdatedTokens()
                }
            }
            
            DispatchQueue.main.async {
                self.notifySubscribersOfUpdatedTokens()
            }
        } else {
            rateLimitedUpdater?.run()
        }
    }

    private func notifySubscribersOfUpdatedTokens() {
        //TODO not efficient. But how many elements can we actually have. Not that many?
        var tickers = [RPCServer: [AlphaWallet.Address: CoinTicker]]()
        var tokens = [TokenObject]()
        //This might slow things down. Especially if it runs too many times unnecessarily
        for each in tokenDataStores {
            if let singleChainTickers = each.tickers {
                tickers[each.server] = singleChainTickers
            } else {
                tickers[each.server] = .init()
            }
            tokens.append(contentsOf: each.enabledObject)
        }

        let nativeCryptoAddressInDatabase = Constants.nativeCryptoAddressInDatabase.eip55String
        tokens.sort {
            //Use `$0.contract` instead of `$0.contractAddress.eip55String` for performance in a loop since we know the former must be in EIP55
            let contract0 = $0.contract
            let contract1 = $1.contract
            //Performance: Don't need to use sameContract(as:) because it's all 0s and we want to be fast
            if contract0 == nativeCryptoAddressInDatabase && contract1 == nativeCryptoAddressInDatabase {
                return $0.server.displayOrderPriority < $1.server.displayOrderPriority
            } else if contract0 == nativeCryptoAddressInDatabase {
                return true
            } else if contract1 == nativeCryptoAddressInDatabase {
                return false
            } else if $0.server != $1.server {
                return $0.server.displayOrderPriority < $1.server.displayOrderPriority
            } else {
                return $0.name < $1.name
            }
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
        case .custom: return 11
        case .heco: return 14
        case .heco_testnet: return 15
        case .taiChi: return 16
        }
    }
}
