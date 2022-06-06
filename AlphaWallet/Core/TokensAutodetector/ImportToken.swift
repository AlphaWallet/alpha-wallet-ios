//
//  ImportToken.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.06.2022.
//

import Foundation
import PromiseKit
import Combine

class ImportToken {
    private let sessions: CurrentValueSubject<ServerDictionary<WalletSession>, Never>
    private let assetDefinitionStore: AssetDefinitionStore
    private let tokenFetchers: AtomicDictionary<RPCServer, TokenFetcher> = .init()

    private let tokensDataStore: TokensDataStore
    var wallet: Wallet {
        sessions.value.anyValue.account
    }

    init(sessions: CurrentValueSubject<ServerDictionary<WalletSession>, Never>, tokensDataStore: TokensDataStore, assetDefinitionStore: AssetDefinitionStore) {
        self.sessions = sessions
        self.tokensDataStore = tokensDataStore
        self.assetDefinitionStore = assetDefinitionStore
    }

    //Adding a token may fail if we lose connectivity while fetching the contract details (e.g. name and balance). So we remove the contract from the hidden list (if it was there) so that the app has the chance to add it automatically upon auto detection at startup
    func importToken(for contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool = false) -> Promise<Token> {
        struct ImportTokenError: Error { }

        return firstly {
            getOrCreateTokenFetcher(for: server).fetchTokenOrContract(for: contract, onlyIfThereIsABalance: onlyIfThereIsABalance)
        }.map { operation -> Token in
            if let token = self.tokensDataStore.addOrUpdate(tokensOrContracts: [operation]).first {
                return token
            } else {
                throw ImportTokenError()
            }
        }
    }

    func importToken(token: ERCToken, shouldUpdateBalance: Bool = true) -> Token {
        let token = tokensDataStore.addCustom(tokens: [token], shouldUpdateBalance: shouldUpdateBalance)

        return token[0]
    }

    func fetchContractData(for address: AlphaWallet.Address, server: RPCServer, completion: @escaping (ContractData) -> Void) {
        guard let session = sessions.value[safe: server] else {
            completion(.failed(networkReachable: true))
            return
        }

        let detector = ContractDataDetector(address: address, account: session.account, server: session.server, assetDefinitionStore: assetDefinitionStore)
        detector.fetch(completion: completion)
    }

    func fetchTokenOrContract(for contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool = false) -> Promise<TokenOrContract> {
        return getOrCreateTokenFetcher(for: server)
            .fetchTokenOrContract(for: contract, onlyIfThereIsABalance: onlyIfThereIsABalance)
    }

    private func getOrCreateTokenFetcher(for server: RPCServer) -> TokenFetcher {
        if let fetcher = tokenFetchers[server] {
            return fetcher
        } else {
            let session = sessions.value[server]
            let fetcher: TokenFetcher = SingleChainTokenFetcher(session: session, assetDefinitionStore: assetDefinitionStore)
            tokenFetchers[server] = fetcher

            return fetcher
        }
    }

}
