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
    private (set) public var storage: SwapSupportStateStorage & SwapPairsStorage & SwapToolStorage & SwapRouteStorage & SwapQuoteStorage = InMemoryTokenSwapperStorage()
    private var inflightFetchSupportedServersPublisher: AnyPublisher<[RPCServer], PromiseError>?
    private var inflightFetchSupportedToolsPublisher: AnyPublisher<[SwapTool], Never>?
    private let sessions: AnyPublisher<ServerDictionary<WalletSession>, Never>
    private var cancelable = Set<AnyCancellable>()
    private var reloadSubject = PassthroughSubject<Void, Never>()
    private var loadingStateSubject: CurrentValueSubject<TokenSwapper.LoadingState, Never> = .init(.pending)
    private let reachabilityManager: ReachabilityManagerProtocol
    private let networkProvider: TokenSwapperNetworkProvider
    private let queue = RunLoop.main

    public var loadingStatePublisher: AnyPublisher<TokenSwapper.LoadingState, Never> {
        loadingStateSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public var objectWillChange: AnyPublisher<Void, Never> {
        return Publishers.Merge3(
                storage.allSupportedTools.dropFirst().mapToVoid(),
                storage.supportedServers.dropFirst().mapToVoid(),
                storage.supportedTokens.dropFirst().mapToVoid()
            ).receive(on: queue)
            .eraseToAnyPublisher()
    }

    public init(reachabilityManager: ReachabilityManagerProtocol, sessionProvider: SessionsProvider, networkProvider: TokenSwapperNetworkProvider) {
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
            .map { (_, sessions, _) in sessions }
            .receive(on: RunLoop.main)
            .flatMap { self.fetchAllSupportedTokens(sessions: $0) }
            .sink { [weak loadingStateSubject] swapSupportStates in
                self.storage.addOrUpdate(swapSupportStates: swapSupportStates)
                loadingStateSubject?.send(.done)
            }.store(in: &cancelable)

        reachabilityManager.networkBecomeReachablePublisher
            .receive(on: queue)
            .flatMap { _ in return self.fetchAllSupportedTools() }
            .sink { self.storage.addOrUpdate(tools: $0) }
            .store(in: &cancelable)

        reload()
    }

    public func reload() {
        reloadSubject.send(())
    }

    public func supportState(for server: RPCServer) -> SwapSupportingType {
        return storage.supportState(for: server).supportingType
    }

    public func swapPairs(for server: RPCServer) -> SwapPairs? {
        return storage.swapPairs(for: server)
    }

    public func supports(contractAddress: AlphaWallet.Address, server: RPCServer) -> Bool {
        guard let swapPaints = swapPairs(for: server) else { return false }
        let tokenToSupport = SwappableToken(address: contractAddress, server: server)
        return swapPaints.fromTokens.contains(tokenToSupport)
    }

    public func fetchSupportedTokens(for server: RPCServer) -> AnyPublisher<SwapSupportState, Never> {
        if storage.containsSwapPairs(for: server) {
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
                }.receive(on: queue)
                .handleEvents(receiveOutput: { self.storage.addOrUpdate(swapPairs: $0, for: server) })
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

    public func fetchSwapQuote(fromToken: TokenToSwap, toToken: TokenToSwap, wallet: AlphaWallet.Address, slippage: String, fromAmount: BigUInt, exchange: String) -> AnyPublisher<Result<SwapQuote, SwapError>, Never> {
        return networkProvider.fetchSwapQuote(fromToken: fromToken, toToken: toToken, wallet: wallet, slippage: slippage, fromAmount: fromAmount, exchange: exchange)
            .receive(on: RunLoop.main)
            .map { value -> Result<SwapQuote, SwapError> in
                self.storage.set(swapQuote: value)
                return .success(value)
            }.catch { e -> AnyPublisher<Result<SwapQuote, SwapError>, Never> in
                infoLog("[Swap] Error while fetching swap quote for tokens. Error: \(e)")
                return .just(.failure(e))
            }.eraseToAnyPublisher()
    }

    public func fetchSwapRoute(fromToken: TokenToSwap, toToken: TokenToSwap, slippage: String, fromAmount: BigUInt, exchanges: [String]) -> AnyPublisher<String?, Never> {
        return networkProvider.fetchSwapRoutes(fromToken: fromToken, toToken: toToken, slippage: slippage, fromAmount: fromAmount, exchanges: exchanges)
            .receive(on: RunLoop.main)
            .map { swapRoutes -> String? in
                guard !swapRoutes.isEmpty else { return nil }

                self.storage.addOrUpdate(swapRoutes: swapRoutes)

                guard let pair = TokenSwapper.firstRouteWithExchange(from: swapRoutes) else { return nil }
                self.storage.set(prefferedSwapRoute: pair.prefferedSwapRoute)

                return pair.exchange
            }.catch { e -> AnyPublisher<String?, Never> in
                infoLog("[Swap] Error while fetching swap route for tokens. Error: \(e)")
                return .just(nil)
            }.eraseToAnyPublisher()
    }

    static func firstRouteWithExchange(from swapRoutes: [SwapRoute]) -> (prefferedSwapRoute: SwapRoute, exchange: String)? {
        let route = swapRoutes.first(where: { !$0.tags.isEmpty }) ?? swapRoutes.first
        guard let prefferedSwapRoute = route else { return nil }
        guard let exchange = TokenSwapper.firstExchange(from: prefferedSwapRoute) else { return nil }

        return (prefferedSwapRoute, exchange)
    }

    static func firstExchange(from route: SwapRoute) -> String? {
        return route.steps.first?.tool
    }

    public func buildSwapTransaction(unsignedTransaction: UnsignedSwapTransaction, fromToken: TokenToSwap, fromAmount: BigUInt, toToken: TokenToSwap, toAmount: BigUInt) -> (UnconfirmedTransaction, TransactionType.Configuration) {
        functional.buildSwapTransaction(unsignedTransaction: unsignedTransaction, fromToken: fromToken, fromAmount: fromAmount, toToken: toToken, toAmount: toAmount)
    }

    private func fetchAllSupportedTools() -> AnyPublisher<[SwapTool], Never> {
        if let pendingPublisher = inflightFetchSupportedToolsPublisher { return pendingPublisher }

        let publisher = networkProvider.fetchSupportedTools()
            .receive(on: queue)
            .handleEvents(receiveOutput: { _ in
                self.inflightFetchSupportedToolsPublisher = nil
            }, receiveCompletion: { result in
                guard case .failure(let error) = result else { return }
                infoLog("[Swap] Error while fetching supported chains. Error: \(error)")
            }).share()
            .replaceError(with: [])
            .eraseToAnyPublisher()

        self.inflightFetchSupportedToolsPublisher = publisher

        return publisher
    }

    private func fetchAllSupportedTokens(sessions: ServerDictionary<WalletSession>) -> AnyPublisher<[SwapSupportState], Never> {
        loadingStateSubject.send(.updating)

        let publishers = sessions.values.map { fetchSupportedTokens(for: $0.server) }
        return Publishers.MergeMany(publishers).collect()
            .eraseToAnyPublisher()
    }

    @discardableResult private func fetchSupportedChains() -> AnyPublisher<[RPCServer], PromiseError> {
        if let pendingPublisher = inflightFetchSupportedServersPublisher { return pendingPublisher }

        let publisher = networkProvider.fetchSupportedChains()
            .receive(on: queue)
            .handleEvents(receiveOutput: { _ in
                self.inflightFetchSupportedServersPublisher = nil
            }, receiveCompletion: { result in
                guard case .failure(let error) = result else { return }
                infoLog("[Swap] Error while fetching supported chains. Error: \(error)")
            }).share()
            .eraseToAnyPublisher()

        self.inflightFetchSupportedServersPublisher = publisher

        return publisher
    }
}

extension TokenSwapper {
    enum functional {
    }
}

fileprivate extension TokenSwapper.functional {
    static func buildSwapTransaction(unsignedTransaction: UnsignedSwapTransaction, fromToken: TokenToSwap, fromAmount: BigUInt, toToken: TokenToSwap, toAmount: BigUInt) -> (UnconfirmedTransaction, TransactionType.Configuration) {
        let configuration: TransactionType.Configuration = .swapTransaction(fromToken: fromToken, fromAmount: fromAmount, toToken: toToken, toAmount: toAmount)
        let transaction: UnconfirmedTransaction = .init(transactionType: .prebuilt(unsignedTransaction.server), value: unsignedTransaction.value, recipient: nil, contract: unsignedTransaction.to, data: unsignedTransaction.data, gasLimit: unsignedTransaction.gasLimit, gasPrice: unsignedTransaction.gasPrice)

        return (transaction, configuration)
    }
}
