//
//  ClientSideTokenSourceProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.07.2022.
//

import Foundation
import AlphaWalletCore
import Combine

extension RPCServer {
    var autodetectTokenTypes: [EipTokenType] {
        return [.erc20, .erc721, .erc1155]
    }
}

public class ClientSideTokenSourceProvider: TokenSourceProvider {
    private lazy var tokensAutodetector: TokensAutodetector = {
        let partnerTokensAutodetector = PartnerTokensAutodetector(
            contractToImportStorage: ContractToImportFileStorage(server: session.server),
            tokensDataStore: tokensDataStore,
            importToken: session.importToken,
            server: session.server)

        let transactedTokensAutodetector = TransactedTokensAutodetector(
            tokensDataStore: tokensDataStore,
            importToken: session.importToken,
            session: session,
            blockchainExplorer: session.blockchainExplorer,
            tokenTypes: session.server.autodetectTokenTypes)

        return SingleChainTokensAutodetector(autodetectors: [
            partnerTokensAutodetector,
            transactedTokensAutodetector
        ])
    }()
    private var cancelable = Set<AnyCancellable>()
    private let tokensDataStore: TokensDataStore
    private let refreshSubject = PassthroughSubject<Void, Never>.init()
    private let balanceFetcher: TokenBalanceFetcherType

    public private (set) lazy var addedTokensPublisher: AnyPublisher<[Token], Never> = {
        return tokensDataStore.tokensChangesetPublisher(for: [session.server], predicate: nil)
            .map { changeset -> [Token] in
                switch changeset {
                case .initial, .error: return []
                case .update(let tokens, _, let insertions, _): return insertions.map { tokens[$0] }
                }
            }.replaceError(with: [])
            .filter { !$0.isEmpty }
            .eraseToAnyPublisher()
    }()

    public var tokensPublisher: AnyPublisher<[Token], Never> {
        let initialOrForceSnapshot = Publishers.Merge(Just<Void>(()), refreshSubject)
            .flatMap { [tokensDataStore, session] _ in
                asFuture {
                    await tokensDataStore.tokens(for: [session.server])
                }
            }
            .eraseToAnyPublisher()

        let addedOrChanged = tokensDataStore.enabledTokensPublisher(for: [session.server])
            .dropFirst()

        return Publishers.Merge(initialOrForceSnapshot, addedOrChanged)
            .eraseToAnyPublisher()
    }

    public let session: WalletSession

    public init(session: WalletSession,
                tokensDataStore: TokensDataStore,
                balanceFetcher: TokenBalanceFetcherType) {

        self.session = session
        self.tokensDataStore = tokensDataStore
        self.balanceFetcher = balanceFetcher
    }

    public func start() {
        tokensDataStore.addEthToken(forServer: session.server)

        tokensAutodetector
            .detectedTokensOrContracts
            .map { $0.map { AddOrUpdateTokenAction($0) } }
            .sink { [tokensDataStore] action in
                Task {
                    await tokensDataStore.addOrUpdate(with: action)
                }
            }
            .store(in: &cancelable)

        //NOTE: disabled as delating instances from db caused crash
        Task {
            await tokensAutodetector.start()
        }

        balanceFetcher.delegate = self
    }

    public func stop() {
        cancelable.cancellAll()
        tokensAutodetector.stop()
    }

    deinit {
        stop()
    }

    public func refresh() {
        refreshSubject.send(())
    }

    public func refreshBalance(for tokens: [Token]) {
        balanceFetcher.refreshBalance(for: tokens)
    }

    public func getTokens() async -> [Token] {
        await tokensDataStore.tokens(for: [session.server])
    }
}

extension ClientSideTokenSourceProvider: TokenBalanceFetcherDelegate {
    public func didUpdateBalance(value actions: [AddOrUpdateTokenAction], in fetcher: TokenBalanceFetcher) {
        Task {
            await crashlytics.logLargeNftJsonFiles(for: actions, fileSizeThreshold: 10)
        }
        Task {
            await tokensDataStore.addOrUpdate(with: actions)
        }
    }
}
