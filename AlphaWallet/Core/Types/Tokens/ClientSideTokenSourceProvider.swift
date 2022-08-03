//
//  ClientSideTokenSourceProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.07.2022.
//

import Foundation
import Combine

class ClientSideTokenSourceProvider: TokenSourceProvider {
    private (set) var tokens: [Token] = []

    var objectWillChange: AnyPublisher<Void, Never> {
        tokensHasChangeSubject.eraseToAnyPublisher()
    }

    private lazy var tokensAutodetector: TokensAutodetector = {
        let detectedContractsProvider = DetectedContractsProvider(tokensDataStore: tokensDataStore)
        let autodetector = SingleChainTokensAutodetector(session: session, detectedTokens: detectedContractsProvider, withAutoDetectTransactedTokensQueue: autoDetectTransactedTokensQueue, withAutoDetectTokensQueue: autoDetectTokensQueue, importToken: importToken)
        return autodetector
    }()

    private var cancelable = Set<AnyCancellable>()
    private let tokensDataStore: TokensDataStore
    private let autoDetectTransactedTokensQueue: OperationQueue
    private let autoDetectTokensQueue: OperationQueue
    private let importToken: ImportToken
    private let tokensHasChangeSubject = PassthroughSubject<Void, Never>.init()
    private let refreshSubject = PassthroughSubject<Void, Never>.init()
    private let balanceFetcher: TokenBalanceFetcherType

    var newTokens: AnyPublisher<[Token], Never> {
        return tokensDataStore.enabledTokensChangeset(for: [session.server])
            .map { changeset -> [Token] in
                switch changeset {
                case .initial, .error: return []
                case .update(let tokens, _, let insertions, _): return insertions.map { tokens[$0] }
                }
            }.replaceError(with: [])
            .filter { !$0.isEmpty }
            .eraseToAnyPublisher()
    }

    let session: WalletSession

    init(session: WalletSession, autoDetectTransactedTokensQueue: OperationQueue, autoDetectTokensQueue: OperationQueue, importToken: ImportToken, tokensDataStore: TokensDataStore, balanceFetcher: TokenBalanceFetcherType) {
        self.session = session
        self.tokensDataStore = tokensDataStore
        self.autoDetectTransactedTokensQueue = autoDetectTransactedTokensQueue
        self.autoDetectTokensQueue = autoDetectTokensQueue
        self.importToken = importToken
        self.balanceFetcher = balanceFetcher
    }

    func start() {
        tokensDataStore.addEthToken(forServer: session.server)

        startTokenAutodetection()
        balanceFetcher.delegate = self
        startTokensHandling()
    }

    private func startTokensHandling() {
        let initialOrForceSnapshot = Publishers.Merge(Just<Void>(()), refreshSubject)
            .map { [tokensDataStore, session] _ in tokensDataStore.enabledTokens(for: [session.server]) }
            .eraseToAnyPublisher()

        let addedOrChanged = tokensDataStore.enabledTokensPublisher(for: [session.server])
            .dropFirst()
            .receive(on: RunLoop.main)

        Publishers.Merge(initialOrForceSnapshot, addedOrChanged)
            .sink { [weak self] tokens in
                self?.tokens = tokens
                self?.tokensHasChangeSubject.send(())
            }.store(in: &cancelable)
    }

    private func startTokenAutodetection() {
        tokensAutodetector.tokensOrContractsDetected
            .sink { [tokensDataStore] tokensOrContracts in
                tokensDataStore.addOrUpdate(tokensOrContracts: tokensOrContracts)
            }.store(in: &cancelable)

        tokensAutodetector.start()
    }

    func refresh() {
        refreshSubject.send(())
    }

    func refreshBalance(for tokens: [Token]) {
        balanceFetcher.refreshBalance(for: tokens)
    }

    private class DetectedContractsProvider: DetectedContractsProvideble {
        private let tokensDataStore: TokensDataStore

        init(tokensDataStore: TokensDataStore) {
            self.tokensDataStore = tokensDataStore
        }

        func alreadyAddedContracts(for server: RPCServer) -> [AlphaWallet.Address] {
            tokensDataStore.enabledTokens(for: [server]).map { $0.contractAddress }
        }

        func deletedContracts(for server: RPCServer) -> [AlphaWallet.Address] {
            tokensDataStore.deletedContracts(forServer: server).map { $0.address }
        }

        func hiddenContracts(for server: RPCServer) -> [AlphaWallet.Address] {
            tokensDataStore.hiddenContracts(forServer: server).map { $0.address }
        }

        func delegateContracts(for server: RPCServer) -> [AlphaWallet.Address] {
            tokensDataStore.delegateContracts(forServer: server).map { $0.address }
        }
    }
}

extension ClientSideTokenSourceProvider: TokenBalanceFetcherDelegate {
    func didUpdateBalance(value actions: [AddOrUpdateTokenAction], in fetcher: TokenBalanceFetcher) {
        crashlytics.logLargeNftJsonFiles(for: actions)
        tokensDataStore.addOrUpdate(actions)
    }
}
