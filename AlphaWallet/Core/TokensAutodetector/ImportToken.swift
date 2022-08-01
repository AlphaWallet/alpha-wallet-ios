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
    private let defaultTokens: [(AlphaWallet.Address, RPCServer)] = [
        (Constants.uefaMainnet, Constants.uefaRpcServer),
    ]

    enum ImportTokenError: Error {
        case serverIsDisabled
        case nothingToImport
        case others
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

        addDefaultTokens()
    }

    private func addDefaultTokens() {
        guard !isRunningTests() else { return }

        let defaultTokens = self.defaultTokens
        sessions.filter { !$0.values.isEmpty }
            .first()
            .sink { _ in
                for (address, server) in defaultTokens {
                    _ = firstly {
                        self.importToken(for: address, server: server, onlyIfThereIsABalance: true)
                    }.done { _ in
                        //no-op
                    }.recover { error in
                        if let error = error as? ImportToken.ImportTokenError {
                            switch error {
                            case .serverIsDisabled:
                                //no-op. Since we didn't check if chain is enabled, we just let it be. But if there are other enum-cases, we don't want to eat the errors, we should re-throw those
                                break
                            case .nothingToImport:
                                //no-op. We don't import it, possibly because balance is 0
                                break
                            case .others:
                                throw error
                            }
                        } else {
                            throw error
                        }
                    }
                }
            }.store(in: &cancelable)
    }

    //Adding a token may fail if we lose connectivity while fetching the contract details (e.g. name and balance). So we remove the contract from the hidden list (if it was there) so that the app has the chance to add it automatically upon auto detection at startup
    func importToken(for contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool = false) -> Promise<Token> {
        firstly {
            fetchTokenOrContract(for: contract, server: server, onlyIfThereIsABalance: onlyIfThereIsABalance)
        }.map { [tokensDataStore] operation -> Token in
            switch operation {
            case .none:
                throw ImportTokenError.nothingToImport
            case .ercToken, .token, .delegateContracts, .deletedContracts, .fungibleTokenComplete:
                if let token = tokensDataStore.addOrUpdate(tokensOrContracts: [operation]).first {
                    return token
                } else {
                    throw ImportTokenError.others
                }
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
        firstly { () -> Promise<TokenOrContract> in
            let fetcher = try getOrCreateTokenFetcher(for: server)
            return fetcher.fetchTokenOrContract(for: contract, onlyIfThereIsABalance: onlyIfThereIsABalance)
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
