//
//  ImportToken.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.06.2022.
//

import Foundation
import PromiseKit
import Combine

public protocol TokenImportable {
    func importToken(token: ERCToken, shouldUpdateBalance: Bool) -> Token
    func importToken(for contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool) -> Promise<Token>
}

public protocol ContractDataFetchable {
    func fetchTokenOrContract(for contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool) -> Promise<TokenOrContract>
    func fetchContractData(for contract: AlphaWallet.Address, server: RPCServer, completion: @escaping (ContractData) -> Void)
}

open class ImportToken: TokenImportable, ContractDataFetchable {
    private let defaultTokens: [(AlphaWallet.Address, RPCServer)] = [
        (Constants.uefaMainnet, Constants.uefaRpcServer),
    ]

    enum ImportTokenError: Error {
        case serverIsDisabled
        case nothingToImport
        case others
    }
    private let sessionProvider: SessionsProvider
    private let assetDefinitionStore: AssetDefinitionStore
    private let analytics: AnalyticsLogger
    private let tokenFetchers: AtomicDictionary<RPCServer, TokenFetcher> = .init()
    private let tokensDataStore: TokensDataStore
    private var cancelable = Set<AnyCancellable>()

    public let wallet: Wallet

    public init(sessionProvider: SessionsProvider, wallet: Wallet, tokensDataStore: TokensDataStore, assetDefinitionStore: AssetDefinitionStore, analytics: AnalyticsLogger) {
        self.sessionProvider = sessionProvider
        self.tokensDataStore = tokensDataStore
        self.assetDefinitionStore = assetDefinitionStore
        self.analytics = analytics
        self.wallet = wallet

        addDefaultTokens()
    }

    private func addDefaultTokens() {
        guard !isRunningTests() else { return }

        let defaultTokens = self.defaultTokens
        //NOTE: initally when we set sessions, we want to import uefa tokens, for enabled chain
        sessionProvider.sessions.filter { !$0.values.isEmpty }
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
    open func importToken(for contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool = false) -> Promise<Token> {
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

    open func importToken(token: ERCToken, shouldUpdateBalance: Bool = true) -> Token {
        let token = tokensDataStore.addCustom(tokens: [token], shouldUpdateBalance: shouldUpdateBalance)

        return token[0]
    }

    open func fetchContractData(for contract: AlphaWallet.Address, server: RPCServer, completion: @escaping (ContractData) -> Void) {
        guard let session = sessionProvider.session(for: server) else {
            completion(.failed(networkReachable: true))
            return
        }

        let detector = ContractDataDetector(address: contract, account: session.account, server: session.server, assetDefinitionStore: assetDefinitionStore, analytics: analytics)
        detector.fetch(completion: completion)
    }

    open func fetchTokenOrContract(for contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool = false) -> Promise<TokenOrContract> {
        firstly { () -> Promise<TokenOrContract> in
            let fetcher = try getOrCreateTokenFetcher(for: server)
            return fetcher.fetchTokenOrContract(for: contract, onlyIfThereIsABalance: onlyIfThereIsABalance)
        }
    }

    private func getOrCreateTokenFetcher(for server: RPCServer) throws -> TokenFetcher {
        if let fetcher = tokenFetchers[server] {
            return fetcher
        } else {
            guard let session = sessionProvider.session(for: server) else { throw ImportTokenError.serverIsDisabled }
            let fetcher: TokenFetcher = SingleChainTokenFetcher(session: session, assetDefinitionStore: assetDefinitionStore, analytics: analytics)
            tokenFetchers[server] = fetcher

            return fetcher
        }
    }

}
