// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import BigInt
import Combine
import AlphaWalletAddress
import AlphaWalletCore

public struct SwapSupportState {
    let server: RPCServer
    let supportingType: SwapSupportingType
}

public enum SwapSupportingType {
    case supports
    case notSupports
    case failure(error: Error)
}

open class TokenSwapper: ObservableObject {
    private var store: TokenSwapperStore = InMemoryTokenSwapperStore()
    private var pendingFetchSupportedServersPublisher: AnyPublisher<[RPCServer], PromiseError>?
    private let sessions: AnyPublisher<ServerDictionary<WalletSession>, Never>
    private var cancelable = Set<AnyCancellable>()
    private var reloadSubject = PassthroughSubject<Void, Never>()
    private var loadingStateSubject: CurrentValueSubject<TokenSwapper.LoadingState, Never> = .init(.pending)
    private let reachabilityManager: ReachabilityManagerProtocol
    private let networkProvider: TokenSwapperNetworkProvider

    public var loadingStatePublisher: AnyPublisher<TokenSwapper.LoadingState, Never> {
        loadingStateSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public init(reachabilityManager: ReachabilityManagerProtocol, sessionProvider: SessionsProvider, networkProvider: TokenSwapperNetworkProvider = LiQuestTokenSwapperNetworkProvider()) {
        self.reachabilityManager = reachabilityManager
        self.networkProvider = networkProvider
        self.sessions = sessionProvider.sessions
            .filter { !$0.isEmpty }
            .eraseToAnyPublisher()
    }

    public func start() {
        guard Features.default.isAvailable(.isSwapEnabled) else { return }
        
        reachabilityManager.networkBecomeReachablePublisher
            .combineLatest(sessions, reloadSubject)
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .flatMap { (_, sessions, _) in return self.fetchAllSupportedTokens(sessions: sessions) }
            .sink { [weak loadingStateSubject] swapSupportStates in
                self.store.addOrUpdate(swapSupportStates: swapSupportStates)
                loadingStateSubject?.send(.done)
            }.store(in: &cancelable)

        reload()
    }

    public func reload() {
        DispatchQueue.global(qos: .userInitiated).async { [reloadSubject] in
            reloadSubject.send(())
        }
    }

    public func supportState(for server: RPCServer) -> SwapSupportingType {
        return store.supportState(for: server).supportingType
    }

    public func swapPairs(for server: RPCServer) -> SwapPairs? {
        return store.swapPairs(for: server)
    }

    public func supports(contractAddress: AlphaWallet.Address, server: RPCServer) -> Bool {
        guard let swapPaints = swapPairs(for: server) else { return false }
        let tokenToSupport = SwappableToken(address: contractAddress, server: server)
        return swapPaints.fromTokens.contains(tokenToSupport)
    }

    public func fetchSupportedTokens(for server: RPCServer) -> AnyPublisher<SwapSupportState, Never> {
        if store.containsSwapPairs(for: server) {
            return Just(server)
                .map { SwapSupportState(server: $0, supportingType: .supports) }
                .eraseToAnyPublisher()
        } else {
            return fetchSupportedChains()
                .flatMap { [networkProvider] servers -> AnyPublisher<SwapPairs, PromiseError> in
                    if servers.contains(server) {
                        return networkProvider.fetchSupportedTokens(for: server)
                    } else {
                        return Empty().eraseToAnyPublisher()
                    }
                }.handleEvents(receiveOutput: { [objectWillChange] swapPairs in
                    self.store.addOrUpdate(swapPairs: swapPairs, for: server)
                    objectWillChange.send()
                })
                .map { _ in SwapSupportState(server: server, supportingType: .supports) }
                .catch { [server] e -> AnyPublisher<SwapSupportState, Never> in
                    infoLog("[Swap] Error while fetching supported tokens for chain: \(server). Error: \(e)")

                    return Just(server)
                        .map { SwapSupportState(server: $0, supportingType: .failure(error: e)) }
                        .eraseToAnyPublisher()
                }.replaceEmpty(with: .init(server: server, supportingType: .notSupports))
                .eraseToAnyPublisher()
        }
    }

    public func fetchSwapQuote(fromToken: TokenToSwap, toToken: TokenToSwap, wallet: AlphaWallet.Address, slippage: String, fromAmount: BigUInt) -> AnyPublisher<Result<SwapQuote, SwapError>, Never> {
        return networkProvider.fetchSwapQuote(fromToken: fromToken, toToken: toToken, wallet: wallet, slippage: slippage, fromAmount: fromAmount)
            .map { value -> Result<SwapQuote, SwapError> in return .success(value) }
            .catch { e -> AnyPublisher<Result<SwapQuote, SwapError>, Never> in
                infoLog("[Swap] Error while fetching swap quote for tokens. Error: \(e)")
                return .just(.failure(e))
            }.eraseToAnyPublisher()
    }

    public func buildSwapTransaction(keystore: Keystore, unsignedTransaction: UnsignedSwapTransaction, fromToken: TokenToSwap, fromAmount: BigUInt, toToken: TokenToSwap, toAmount: BigUInt) -> (UnconfirmedTransaction, TransactionType.Configuration) {
        functional.buildSwapTransaction(keystore: keystore, unsignedTransaction: unsignedTransaction, fromToken: fromToken, fromAmount: fromAmount, toToken: toToken, toAmount: toAmount)
    }

    private func fetchAllSupportedTokens(sessions: ServerDictionary<WalletSession>) -> AnyPublisher<[SwapSupportState], Never> {
        loadingStateSubject.send(.updating)

        let publishers = sessions.values.map { fetchSupportedTokens(for: $0.server) }
        return Publishers.MergeMany(publishers).collect()
            .eraseToAnyPublisher()
    }

    @discardableResult private func fetchSupportedChains() -> AnyPublisher<[RPCServer], PromiseError> {
        if let pendingPublisher = pendingFetchSupportedServersPublisher { return pendingPublisher }

        let publisher = networkProvider.fetchSupportedChains()
            .handleEvents(receiveOutput: { _ in
                self.pendingFetchSupportedServersPublisher = nil
            }, receiveCompletion: { [objectWillChange] result in
                if case .failure(let error) = result {
                    infoLog("[Swap] Error while fetching supported chains. Error: \(error)")
                }

                objectWillChange.send()
            }).share()
            .eraseToAnyPublisher()

        self.pendingFetchSupportedServersPublisher = publisher

        return publisher
    }
}

extension TokenSwapper {
    enum functional {
    }
}

fileprivate extension TokenSwapper.functional {
    static func buildSwapTransaction(keystore: Keystore, unsignedTransaction: UnsignedSwapTransaction, fromToken: TokenToSwap, fromAmount: BigUInt, toToken: TokenToSwap, toAmount: BigUInt) -> (UnconfirmedTransaction, TransactionType.Configuration) {
        let configuration: TransactionType.Configuration = .swapTransaction(fromToken: fromToken, fromAmount: fromAmount, toToken: toToken, toAmount: toAmount )
        let transactionType: TransactionType = .prebuilt(unsignedTransaction.server)
        let transaction: UnconfirmedTransaction = .init(transactionType: transactionType, value: unsignedTransaction.value, recipient: unsignedTransaction.from, contract: unsignedTransaction.to, data: unsignedTransaction.data, gasLimit: unsignedTransaction.gasLimit, gasPrice: unsignedTransaction.gasPrice)
        return (transaction, configuration)
    }
}
