// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import BigInt
import Combine
import AlphaWalletAddress
import AlphaWalletCore

class TokenSwapper: ObservableObject {
    private var store: TokenSwapperStore = InMemoryTokenSwapperStore()
    private var pendingFetchSupportedServersPublisher: AnyPublisher<[RPCServer], PromiseError>?
    private let sessions: AnyPublisher<ServerDictionary<WalletSession>, Never>
    private var cancelable = Set<AnyCancellable>()
    private var reloadSubject = PassthroughSubject<Void, Never>()
    private var loadingStateSubject: CurrentValueSubject<TokenSwapper.LoadingState, Never> = .init(.pending)

    private let reachabilityManager: ReachabilityManagerProtocol
    private let networkProvider: TokenSwapperNetworkProvider

    var loadingStatePublisher: AnyPublisher<TokenSwapper.LoadingState, Never> {
        loadingStateSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    init(reachabilityManager: ReachabilityManagerProtocol, sessionProvider: SessionsProvider, networkProvider: TokenSwapperNetworkProvider = LiQuestTokenSwapperNetworkProvider()) {
        self.reachabilityManager = reachabilityManager
        self.networkProvider = networkProvider
        self.sessions = sessionProvider.sessions
            .filter { !$0.isEmpty }
            .eraseToAnyPublisher()
    }

    func start() {
        guard Features.default.isAvailable(.isSwapEnabled) else { return }
        
        reachabilityManager.networkBecomeReachablePublisher
            .combineLatest(sessions, reloadSubject)
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .flatMapLatest { (_, sessions, _) in return self.fetchAllSupportedTokens(sessions: sessions) }
            .sink { [weak self] _ in
                self?.loadingStateSubject.send(.done)
            }.store(in: &cancelable)

        reload()
    }

    func reload() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.reloadSubject.send(())
        }
    }

    func supports(forServer server: RPCServer) -> Bool {
        return store.supports(forServer: server)
    }

    func swapPairs(forServer server: RPCServer) -> SwapPairs? {
        return store.swapPairs(forServer: server)
    }

    func supports(contractAddress: AlphaWallet.Address, server: RPCServer) -> Bool {
        guard let swapPaints = swapPairs(forServer: server) else { return false }
        let tokenToSupport = SwappableToken(address: contractAddress, server: server)
        return swapPaints.fromTokens.contains(tokenToSupport)
    }

    func fetchSupportedTokens(forServer server: RPCServer) -> AnyPublisher<RPCServer, Never> {
        if store.containsSwapPairs(forServer: server) {
            return Just(server).eraseToAnyPublisher()
        } else {
            return fetchSupportedChains()
                .flatMap { _ -> AnyPublisher<SwapPairs, PromiseError> in
                    if self.store.supports(forServer: server) {
                        return self.networkProvider.fetchSupportedTokens(forServer: server)
                    } else {
                        return Empty().eraseToAnyPublisher()
                    }
                }.handleEvents(receiveOutput: { swapPairs in
                    self.store.addOrUpdate(swapPairs: swapPairs, forServer: server)
                    self.objectWillChange.send()
                }).map { _ in server }
                .replaceError(with: server)
                .replaceEmpty(with: server)
                .eraseToAnyPublisher()
        }
    }

    func fetchSwapQuote(fromToken: TokenToSwap, toToken: TokenToSwap, wallet: AlphaWallet.Address, slippage: Double, fromAmount: BigUInt) -> AnyPublisher<Result<SwapQuote, SwapError>, Never> {
        return networkProvider.fetchSwapQuote(fromToken: fromToken, toToken: toToken, wallet: wallet, slippage: slippage, fromAmount: fromAmount)
            .map { value -> Result<SwapQuote, SwapError> in return .success(value) }
            .catch({ e -> AnyPublisher<Result<SwapQuote, SwapError>, Never> in
                Just<Result<SwapQuote, SwapError>>(.failure(e)).eraseToAnyPublisher()
            }).eraseToAnyPublisher()
    }

    func buildSwapTransaction(keystore: Keystore, unsignedTransaction: UnsignedSwapTransaction, fromToken: TokenToSwap, fromAmount: BigUInt, toToken: TokenToSwap, toAmount: BigUInt) -> (UnconfirmedTransaction, TransactionConfirmationViewModel.Configuration) {
        functional.buildSwapTransaction(keystore: keystore, unsignedTransaction: unsignedTransaction, fromToken: fromToken, fromAmount: fromAmount, toToken: toToken, toAmount: toAmount)
    }

    private func fetchAllSupportedTokens(sessions: ServerDictionary<WalletSession>) -> AnyPublisher<Void, Never> {
        loadingStateSubject.send(.updating)

        let publishers = sessions.values.map { fetchSupportedTokens(forServer: $0.server) }
        return Publishers.MergeMany(publishers).collect()
            .mapToVoid()
            .eraseToAnyPublisher()
    }

    @discardableResult private func fetchSupportedChains() -> AnyPublisher<[RPCServer], PromiseError> {
        if let pendingPublisher = pendingFetchSupportedServersPublisher { return pendingPublisher }

        let publisher = networkProvider.fetchSupportedChains()
            .handleEvents(receiveOutput: { servers in
                self.pendingFetchSupportedServersPublisher = nil
                self.store.addOrUpdate(servers: servers)

                self.objectWillChange.send()
            })
            .share()
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
    static func buildSwapTransaction(keystore: Keystore, unsignedTransaction: UnsignedSwapTransaction, fromToken: TokenToSwap, fromAmount: BigUInt, toToken: TokenToSwap, toAmount: BigUInt) -> (UnconfirmedTransaction, TransactionConfirmationViewModel.Configuration) {
        let configuration: TransactionConfirmationViewModel.Configuration = .swapTransaction(fromToken: fromToken, fromAmount: fromAmount, toToken: toToken, toAmount: toAmount )
        let transactionType: TransactionType = .prebuilt(unsignedTransaction.server)
        let transaction: UnconfirmedTransaction = .init(transactionType: transactionType, value: unsignedTransaction.value, recipient: unsignedTransaction.from, contract: unsignedTransaction.to, data: unsignedTransaction.data, gasLimit: unsignedTransaction.gasLimit, gasPrice: unsignedTransaction.gasPrice)
        return (transaction, configuration)
    }
}
