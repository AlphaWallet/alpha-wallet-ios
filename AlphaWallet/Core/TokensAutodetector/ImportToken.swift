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
    enum ImportTokenError: Error {
        case serverIsDisabled
    }
    private let sessions: CurrentValueSubject<ServerDictionary<WalletSession>, Never>
    private let assetDefinitionStore: AssetDefinitionStore
    private let analyticsCoordinator: AnalyticsCoordinator
    private let tokenFetchers: AtomicDictionary<RPCServer, TokenFetcher> = .init()
    private let tokensDataStore: TokensDataStore
    private var cancelable = Set<AnyCancellable>()

    let wallet: Wallet

    init(sessions: CurrentValueSubject<ServerDictionary<WalletSession>, Never>, wallet: Wallet, tokensDataStore: TokensDataStore, assetDefinitionStore: AssetDefinitionStore, analyticsCoordinator: AnalyticsCoordinator) {
        self.sessions = sessions
        self.tokensDataStore = tokensDataStore
        self.assetDefinitionStore = assetDefinitionStore
        self.analyticsCoordinator = analyticsCoordinator
        self.wallet = wallet

        addUefaTokenIfAny()
    }

    private func addUefaTokenIfAny() {
        guard !isRunningTests() else { return }
        
        //NOTE: initally when we set sessions, we want to import uefa tokens, for enabled chain
        sessions.filter { !$0.values.isEmpty }
            .first()
            .sink { _ in
                let server = Constants.uefaRpcServer
                self.importToken(for: Constants.uefaMainnet, server: server, onlyIfThereIsABalance: true)
                    .done { _ in }
                    .cauterize()
            }.store(in: &cancelable)
    }

    //Adding a token may fail if we lose connectivity while fetching the contract details (e.g. name and balance). So we remove the contract from the hidden list (if it was there) so that the app has the chance to add it automatically upon auto detection at startup
    func importToken(for contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool = false) -> Promise<Token> {
        struct ImportTokenError: Error { }

        return firstly {
            fetchTokenOrContract(for: contract, server: server, onlyIfThereIsABalance: onlyIfThereIsABalance)
        }.map { [tokensDataStore] operation -> Token in
            if let token = tokensDataStore.addOrUpdate(tokensOrContracts: [operation]).first {
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

    func fetchContractData(for contract: AlphaWallet.Address, server: RPCServer, completion: @escaping (ContractData) -> Void) {
        guard let session = sessions.value[safe: server] else {
            completion(.failed(networkReachable: true))
            return
        }

        let detector = ContractDataDetector(address: contract, account: session.account, server: session.server, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator)
        detector.fetch(completion: completion)
    }

    func fetchTokenOrContract(for contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool = false) -> Promise<TokenOrContract> {
        do {
            let fetcher = try getOrCreateTokenFetcher(for: server)
            return fetcher.fetchTokenOrContract(for: contract, onlyIfThereIsABalance: onlyIfThereIsABalance)
        } catch {
            return .init(error: error)
        }
    }

    private func getOrCreateTokenFetcher(for server: RPCServer) throws -> TokenFetcher {
        if let fetcher = tokenFetchers[server] {
            return fetcher
        } else {
            guard let session = sessions.value[safe: server] else { throw ImportTokenError.serverIsDisabled }
            let fetcher: TokenFetcher = SingleChainTokenFetcher(session: session, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator)
            tokenFetchers[server] = fetcher

            return fetcher
        }
    }

}
