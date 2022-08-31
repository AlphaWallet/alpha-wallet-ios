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
        let detectedContractsProvider = DetectedContractsProvider(tokensDataStore: tokensDataStore)
        let autodetector = SingleChainTokensAutodetector(session: session, detectedTokens: detectedContractsProvider, withAutoDetectTransactedTokensQueue: autoDetectTransactedTokensQueue, withAutoDetectTokensQueue: autoDetectTokensQueue, importToken: importToken)
        return autodetector
    }()

    private var cancelable = Set<AnyCancellable>()
    private let tokensDataStore: TokensDataStore
    private let autoDetectTransactedTokensQueue: OperationQueue
    private let autoDetectTokensQueue: OperationQueue
    private let importToken: ImportToken
    private let refreshSubject = PassthroughSubject<Void, Never>.init()
    private let balanceFetcher: TokenBalanceFetcherType

    public private (set) lazy var newTokens: AnyPublisher<[Token], Never> = {
        return tokensDataStore.enabledTokensChangeset(for: [session.server])
            .map { changeset -> [Token] in
                switch changeset {
                case .initial, .error: return []
                case .update(let tokens, _, let insertions, _): return insertions.map { tokens[$0] }
                }
            }.replaceError(with: [])
            .filter { !$0.isEmpty }
            .eraseToAnyPublisher()
    }()

    public var tokens: [Token] { tokensDataStore.enabledTokens(for: [session.server]) }

    private (set) lazy public var tokensPublisher: AnyPublisher<[Token], Never> = {
        let initialOrForceSnapshot = Publishers.Merge(Just<Void>(()), refreshSubject)
            .map { [tokensDataStore, session] _ in tokensDataStore.enabledTokens(for: [session.server]) }
            .eraseToAnyPublisher()

        let addedOrChanged = tokensDataStore.enabledTokensPublisher(for: [session.server])
            .dropFirst()

        return Publishers.Merge(initialOrForceSnapshot, addedOrChanged)
            .eraseToAnyPublisher()
    }()

    public let session: WalletSession

    public init(session: WalletSession, autoDetectTransactedTokensQueue: OperationQueue, autoDetectTokensQueue: OperationQueue, importToken: ImportToken, tokensDataStore: TokensDataStore, balanceFetcher: TokenBalanceFetcherType) {
        self.session = session
        self.tokensDataStore = tokensDataStore
        self.autoDetectTransactedTokensQueue = autoDetectTransactedTokensQueue
        self.autoDetectTokensQueue = autoDetectTokensQueue
        self.importToken = importToken
        self.balanceFetcher = balanceFetcher
    }

    public func start() {
        tokensDataStore.addEthToken(forServer: session.server)

        startTokenAutodetection()
        balanceFetcher.delegate = self
    }

    private func startTokenAutodetection() {
        tokensAutodetector.tokensOrContractsDetected
            .sink { [tokensDataStore] tokensOrContracts in
                tokensDataStore.addOrUpdate(tokensOrContracts: tokensOrContracts)
            }.store(in: &cancelable)

        tokensAutodetector.start()
    }

    public func refresh() {
        refreshSubject.send(())
    }

    public func refreshBalance(for tokens: [Token]) {
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
    public func didUpdateBalance(value actions: [AddOrUpdateTokenAction], in fetcher: TokenBalanceFetcher) {
        crashlytics?.logLargeNftJsonFiles(for: actions, fileSizeThreshold: 10)
        tokensDataStore.addOrUpdate(actions)
    }
}
