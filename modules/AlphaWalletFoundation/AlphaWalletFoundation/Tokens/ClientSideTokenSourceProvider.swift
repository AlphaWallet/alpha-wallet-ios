//
//  ClientSideTokenSourceProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.07.2022.
//

import Foundation
import Combine

public class ClientSideTokenSourceProvider: TokenSourceProvider {
    private lazy var tokensAutodetector: TokensAutodetector = {
        let contractToImportStorage = ContractToImportFileStorage(server: session.server)
        let autodetector = SingleChainTokensAutodetector(session: session, contractToImportStorage: contractToImportStorage, tokensDataStore: tokensDataStore, withAutoDetectTransactedTokensQueue: autoDetectTransactedTokensQueue, withAutoDetectTokensQueue: autoDetectTokensQueue, importToken: session.importToken)
        return autodetector
    }()
    private var cancelable = Set<AnyCancellable>()
    private let tokensDataStore: TokensDataStore
    private let autoDetectTransactedTokensQueue: OperationQueue
    private let autoDetectTokensQueue: OperationQueue
    private let refreshSubject = PassthroughSubject<Void, Never>.init()
    private let balanceFetcher: TokenBalanceFetcherType

    public private (set) lazy var addedTokensPublisher: AnyPublisher<[Token], Never> = {
        return tokensDataStore.tokensChangesetPublisher(for: [session.server])
            .map { changeset -> [Token] in
                switch changeset {
                case .initial, .error: return []
                case .update(let tokens, _, let insertions, _): return insertions.map { tokens[$0] }
                }
            }.replaceError(with: [])
            .filter { !$0.isEmpty }
            .eraseToAnyPublisher()
    }()

    public var tokens: [Token] { tokensDataStore.tokens(for: [session.server]) }

    public var tokensPublisher: AnyPublisher<[Token], Never> {
        let initialOrForceSnapshot = Publishers.Merge(Just<Void>(()), refreshSubject)
            .map { [tokensDataStore, session] _ in tokensDataStore.tokens(for: [session.server]) }
            .eraseToAnyPublisher()

        let addedOrChanged = tokensDataStore.enabledTokensPublisher(for: [session.server])
            .dropFirst()

        return Publishers.Merge(initialOrForceSnapshot, addedOrChanged)
            .eraseToAnyPublisher()
    }

    public let session: WalletSession

    public init(session: WalletSession,
                autoDetectTransactedTokensQueue: OperationQueue,
                autoDetectTokensQueue: OperationQueue,
                tokensDataStore: TokensDataStore,
                balanceFetcher: TokenBalanceFetcherType) {

        self.session = session
        self.tokensDataStore = tokensDataStore
        self.autoDetectTransactedTokensQueue = autoDetectTransactedTokensQueue
        self.autoDetectTokensQueue = autoDetectTokensQueue
        self.balanceFetcher = balanceFetcher
    }

    public func start() {
        tokensDataStore.addEthToken(forServer: session.server)

        startTokenAutodetection()
        balanceFetcher.delegate = self
    }

    private func startTokenAutodetection() {
        tokensAutodetector
            .tokensOrContractsDetected
            .sink { [tokensDataStore] in tokensDataStore.addOrUpdate(tokensOrContracts: $0) }
            .store(in: &cancelable)

        tokensAutodetector.start()
    }

    public func refresh() {
        refreshSubject.send(())
    }

    public func refreshBalance(for tokens: [Token]) {
        balanceFetcher.refreshBalance(for: tokens)
    }
}

extension ClientSideTokenSourceProvider: TokenBalanceFetcherDelegate {
    public func didUpdateBalance(value actions: [AddOrUpdateTokenAction], in fetcher: TokenBalanceFetcher) {
        crashlytics.logLargeNftJsonFiles(for: actions, fileSizeThreshold: 10)
        tokensDataStore.addOrUpdate(with: actions)
    }
}
