//
//  SwapOptionsConfigurator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import Foundation
import Combine
import BigInt
import CombineExt

public enum TransactionDeadline {
    case value(Double)
    case undefined
}

public final class SwapOptionsConfigurator {
    //NOTE: special flag for identifying first server validation. Initially selected token resets with first matching supported token, when screen get loaded.
    // to avoid this we use flag, for selected token validation. `if it contains in from tokens in SwapQuote`
    private var isInitialServerValidation: Bool = true
    private var errorSubject: PassthroughSubject<TokenSwapper.TokenSwapperError?, Never> = .init()
    private var cancelable = Set<AnyCancellable>()
    private let tokensService: TokensService
    private var fromAmountSubject: CurrentValueSubject<BigUInt?, Never> = .init(nil)
    private var fetchSwapQuoteStateSubject: CurrentValueSubject<SwapQuoteState, Never> = .init(.pendingInput)
    @Published public private(set) var sessions: [WalletSession]
    @Published public private(set) var server: RPCServer
    @Published public private(set) var swapPair: SwapPair
    public var lastSwapQuote: SwapQuote? {
        tokenSwapper.storage.swapQuote
    }
    public var fromAmount: BigUInt? {
        fromAmountSubject.value.flatMap { BigUInt($0) }
    }

    public var activeValidServer: RPCServer {
        swapPair.from.server
    }

    public var fetchSwapQuoteState: AnyPublisher<SwapQuoteState, Never> {
        fetchSwapQuoteStateSubject.removeDuplicates()
            .eraseToAnyPublisher()
    }

    public var session: WalletSession {
        sessions.first(where: { $0.server == server })!
    }

    public var slippage: CurrentValueSubject<SwapSlippage, Never> = .init(.tenPercents)

    private (set) lazy var fromAndToTokensPublisher: AnyPublisher<FromAndToTokens?, Never> = {
        return $swapPair.map { $0.asFromAndToTokens }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }()

    public var error: AnyPublisher<TokenSwapper.TokenSwapperError?, Never> {
        errorSubject.eraseToAnyPublisher()
    }

    public let tokenSwapper: TokenSwapper

    public private (set) lazy var validatedAmount: AnyPublisher<BigUInt, Never> = {
        let hasFromAndToSwapTokens = fromAndToTokensPublisher
            .map { $0 != nil }

        return fromAmountSubject.combineLatest(hasFromAndToSwapTokens) { amount, hasSwapToken -> BigUInt? in
            return hasSwapToken ? amount : nil
        }.compactMap { $0.flatMap { BigUInt($0) } }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }()

    public private (set) lazy var swapQuote: AnyPublisher<SwapQuote?, Never> = {
        //NOTE: here we use debounce to reduce requests calls when user quickly switches beetwen tokens, or types amount to swap
        let amount = validatedAmount.debounce(for: .milliseconds(250), scheduler: RunLoop.main)
        let fromAndToTokens = fromAndToTokensPublisher.compactMap { $0 }
        let slippage = slippage.map { String($0.doubleValue).droppedTrailingZeros }
        let exchanges = tokenSwapper.storage.selectedTools.map { $0.map { $0.key }.filter { $0.nonEmpty } }
        let swapParams = Publishers.CombineLatest4(fromAndToTokens, amount, slippage, exchanges)

        let prefferedExchange = tokenSwapper.storage.prefferedExchange
            .removeDuplicates()
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)

        return Publishers.CombineLatest(swapParams, prefferedExchange)
            .compactMap { [weak self] (params, prefferedExchange) -> AnyPublisher<SwapQuote?, Never>? in
                if params.1 == .zero {
                    return .just(nil)
                } else {
                    return self?.fetchSwapQuote(tokens: params.0, amount: params.1, slippage: params.2, exchanges: params.3, prefferedExchange: prefferedExchange)
                }
            }.switchToLatest()
            .share()
            .prepend(nil)
            .eraseToAnyPublisher()
    }()

    public init(sessionProvider: SessionsProvider,
                swapPair: SwapPair,
                tokensService: TokensService,
                tokenSwapper: TokenSwapper) {

        self.tokenSwapper = tokenSwapper
        self.sessions = functional.sortSessionsWithMainnetsFirst(sessions: sessionProvider.activeSessions.values)
        self.server = swapPair.from.server
        self.swapPair = swapPair
        self.tokensService = tokensService

        invalidateSessionsWhenSupportedTokensChanged()
        fetchSupportedTokensForSelectedServer()
        resetToTokenForNonSupportedSwapPair()
    }

    public func set(token: Token, selection: SwapTokens.TokenSelection) {
        var pair = swapPair
        switch selection {
        case .to: pair.to = token
        case .from: pair.from = token
        }
        swapPair = pair
    }

    public func set(fromToken token: Token) {
        var pair = swapPair
        pair.from = token
        swapPair = pair
    }

    public func togglePair() {
        guard let toToken = swapPair.to else { return }
        swapPair = SwapPair(from: toToken, to: swapPair.from)
    }

    public func swapPairs(for server: RPCServer) -> SwapPairs? {
        return tokenSwapper.swapPairs(for: server)
    }

    public func start() {
        tokenSwapper.reload()
    }

    public func set(fromAmount amount: BigUInt?) {
        fromAmountSubject.value = amount
    }

    public func set(server: RPCServer) {
        self.server = server
    }

    public func isAvailable(server: RPCServer) async -> Bool {
        switch tokenSwapper.supportState(for: server) {
        case .supports:
            return await hasAnySuportedToken(forServer: server)
        case .notSupports, .failure:
            return false
        }
    }

    /// Fetches supported tokens for active server
    private func fetchSupportedTokensForSelectedServer() {
        $server.removeDuplicates()
            .flatMap { [tokenSwapper] in tokenSwapper.fetchSupportedTokens(for: $0) }
            .sink { [weak self] state in
                guard let strongSelf = self else { return }

                strongSelf.validateSwapPair(forServer: state.server, isInitialServerValidation: strongSelf.isInitialServerValidation)
                strongSelf.isInitialServerValidation = false
            }.store(in: &cancelable)
    }

    /// Invalidates sessions when supportedTokens changed
    private func invalidateSessionsWhenSupportedTokensChanged() {
        tokenSwapper.objectWillChange
            .sink { [weak self] _ in self?.invalidateSessions() }
            .store(in: &cancelable)
    }

    private func invalidateSessions() {
        sessions = sessions
    }

    /// Resets `to token` if its not supported when from token has changed
    private func resetToTokenForNonSupportedSwapPair() {
        $swapPair.dropFirst() //NOTE: we dont want to fire it for initially generated pair
            .map { $0.from }
            .removeDuplicates()
            .sink { [weak self] newFromToken in
                guard let toToken = self?.swapPair.to.flatMap({ SwappableToken(address: $0.contractAddress, server: $0.server) }) else {
                    return
                }

                guard let swapPairs = self?.tokenSwapper.swapPairs(for: newFromToken.server) else { return }
                let fromToken = SwappableToken(address: newFromToken.contractAddress, server: newFromToken.server)
                let toTokens = swapPairs.getToTokens(forFromToken: fromToken)

                if toTokens.contains(toToken) {
                    //no-op
                } else {
                    self?.swapPair = .init(from: newFromToken)
                }
            }.store(in: &cancelable)
    }

    /// Fetches swap quote for selected swap parameters, skips fetching swap routes for predefined `prefferedExchange`
    private func fetchSwapQuote(tokens: FromAndToTokens, amount: BigUInt, slippage: String, exchanges: [String], prefferedExchange: String?) -> AnyPublisher<SwapQuote?, Never> {
        let wallet = session.account.address
        fetchSwapQuoteStateSubject.send(.fetching)

        return Just(tokens)
            .flatMapLatest { [tokenSwapper] tokens -> AnyPublisher<String?, Never> in
                if let exchange = prefferedExchange {
                    return .just(exchange)
                } else {
                    return tokenSwapper.fetchSwapRoute(fromToken: tokens.from, toToken: tokens.to, slippage: slippage, fromAmount: amount, exchanges: exchanges)
                }
            }.flatMapLatest { [tokenSwapper] exchange -> AnyPublisher<Result<SwapQuote, SwapError>, Never> in
                guard let exchange = exchange else { return .just(.failure(.tokenOrSwapQuoteNotFound)) }
                return tokenSwapper.fetchSwapQuote(fromToken: tokens.from, toToken: tokens.to, wallet: wallet, slippage: slippage, fromAmount: amount, exchange: exchange)
            }.handleEvents(receiveOutput: { [weak fetchSwapQuoteStateSubject, weak errorSubject] result in
                switch result {
                case .success(let swapQuote):
                    fetchSwapQuoteStateSubject?.send(.completed(error: nil))
                case .failure(let error):
                    fetchSwapQuoteStateSubject?.send(.completed(error: error))
                    errorSubject?.send(.general(error: error))
                }
            }).map { try? $0.get() }
            .eraseToAnyPublisher()
    }

    private func validateSwapPair(forServer server: RPCServer, isInitialServerValidation: Bool) {
        Task { @MainActor in
            do {
                let tokens = try await supportedTokens(forServer: server)
                let token = try firstSupportedFromToken(forServer: server, tokens: tokens)
                if isInitialServerValidation && swapPair.from.contractAddress != token.contractAddress {
                    let _ = try firstSupportedFromToken(forServer: server, tokens: [swapPair.from])
                    //NOTE: no changes needed as current swapPair.from supports
                } else {
                    swapPair = SwapPair(from: token, to: nil)
                }
            } catch TokenSwapper.TokenSwapperError.fromTokenNotFound {
                errorSubject.send(.fromTokenNotFound)
            }
        }
    }

    private func hasAnySuportedToken(forServer server: RPCServer) async -> Bool {
        guard let tokens = try? await supportedTokens(forServer: server) else { return false }
        let token = try? firstSupportedFromToken(forServer: server, tokens: tokens)
        return token != nil
    }

    private func supportedTokens(forServer server: RPCServer) async throws -> [Token] {
        guard swapPairs(for: server) != nil else { throw TokenSwapper.TokenSwapperError.swapPairNotFound }
        return await tokensService.tokens(for: [server])
    }

    private func firstSupportedFromToken(forServer server: RPCServer, tokens: [Token]) throws -> Token {
        guard let swapPairs = swapPairs(for: server) else { throw TokenSwapper.TokenSwapperError.swapPairNotFound }

        guard let token = tokens.first(where: {
            swapPairs.fromTokens.contains(SwappableToken(address: $0.contractAddress, server: $0.server))
        }) else {
            throw TokenSwapper.TokenSwapperError.fromTokenNotFound
        }

        let toTokens = swapPairs.getToTokens(forFromToken: .init(address: token.contractAddress, server: token.server))
        if toTokens.isEmpty {
            throw TokenSwapper.TokenSwapperError.fromTokenNotFound
        } else {
            return token
        }
    }
}

public extension SwapOptionsConfigurator {
    var tokensWithTheirSwapQuote: AnyPublisher<(swapQuote: SwapQuote, tokens: FromAndToTokens)?, Never> {
        return swapQuote.combineLatest(fromAndToTokensPublisher)
            .map { (swapRoutes, tokens) -> (swapRoutes: SwapQuote, tokens: FromAndToTokens)? in
                guard let swapQuote = swapRoutes, let tokens = tokens, swapQuote.action.fromToken == tokens.from && swapQuote.action.toToken == tokens.to else { return nil }
                return (swapQuote, tokens)
            }.eraseToAnyPublisher()
        return .just(nil)
    }
}

extension SwapOptionsConfigurator {
    class functional {}
}

fileprivate extension SwapOptionsConfigurator.functional {
    static func sortSessionsWithMainnetsFirst(sessions: [WalletSession]) -> [WalletSession] {
        let sortedSessions = sessions.sorted(by: { $0.server.displayOrderPriority < $1.server.displayOrderPriority })
        var mainnetsSessions = [WalletSession]()
        var testnetsSessions = [WalletSession]()
        var returnedSessions = [WalletSession]()
        sortedSessions.forEach { session in
            if session.server.isTestnet {
                testnetsSessions.append(session)
            } else {
                mainnetsSessions.append(session)
            }
        }
        returnedSessions.append(contentsOf: mainnetsSessions)
        returnedSessions.append(contentsOf: testnetsSessions)
        return returnedSessions
    }
}
