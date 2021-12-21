//Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Result
import PromiseKit

///This contains tokens across multiple-chains
class TokenCollection {
    private var subscribers: [(Swift.Result<TokensViewModel, TokenError>) -> Void] = []
    private var rateLimitedUpdater: RateLimiter?
    private let filterTokensCoordinator: FilterTokensCoordinator

    let tokenDataStores: [TokensDataStore]
    private var privateTokenObjects: [TokenObject] = []
    private let config: Config = Config()

    init(filterTokensCoordinator: FilterTokensCoordinator, tokenDataStores: [TokensDataStore]) {
        self.filterTokensCoordinator = filterTokensCoordinator
        self.tokenDataStores = tokenDataStores

        for each in tokenDataStores {
            each.delegate = self
        }
    }

    func fetch() {
        notifySubscribersOfUpdatedTokens()
    }

    func subscribe(_ subscribe: @escaping (_ result: Swift.Result<TokensViewModel, TokenError>) -> Void) {
        subscribers.append(subscribe)
    }

    var tokenObjects: Promise<[TokenObject]> {
        return Promise<[TokenObject]> { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }
                //NOTE: Fetch if empty, cound be if called before fetch() get called
                if strongSelf.privateTokenObjects.isEmpty {
                    strongSelf.privateTokenObjects = strongSelf.tokenDataStores.compactMap { $0.enabledObject }.flatMap { $0 }
                }

                seal.fulfill(strongSelf.privateTokenObjects)
            }
        }
    }

    func tokenObjectPromise(for addressAndRPCServer: AddressAndRPCServer) -> Promise<TokenObject?> {
        return Promise { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }
                let token = strongSelf.tokenObject(addressAndRPCServer: addressAndRPCServer)

                seal.fulfill(token)
            }
        }
    }

    func tokenObjectPromise(forContract contract: AlphaWallet.Address) -> Promise<TokenObject?> {
        tokenObjects.map { tokenObjects -> TokenObject? in
            tokenObjects.first(where: { $0.contractAddress == contract })
        }
    }

    func tokenObject(addressAndRPCServer: AddressAndRPCServer) -> TokenObject? {
        if let token = privateTokenObjects.first(where: { $0.addressAndRPCServer == addressAndRPCServer }) {
            return token
        } else {
            return tokenDataStores.first(where: { $0.server == addressAndRPCServer.server }).flatMap { $0.token(forContract: addressAndRPCServer.address) }
        }
    }
}

extension TokenCollection: TokensDataStoreDelegate {
    func didUpdate(in tokensDataStore: TokensDataStore, refreshImmediately: Bool = false) {
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
        privateTokenObjects = tokenDataStores.compactMap { $0.enabledObject }.flatMap { $0 }
        let tokensViewModel = TokensViewModel(filterTokensCoordinator: filterTokensCoordinator, tokens: privateTokenObjects, config: config)
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
        case .arbitrum: return 25
        case .palm: return 26
        case .palmTestnet: return 27
        }
    }
}
