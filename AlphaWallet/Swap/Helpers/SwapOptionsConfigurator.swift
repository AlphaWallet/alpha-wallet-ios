//
//  SwapOptionsConfigurator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import Foundation
import Combine 
import BigInt

enum TransactionDeadline {
    case value(Double)
    case undefined
}

final class SwapOptionsConfigurator {
    //NOTE: special flag for identifying first server validation. Initially selected token resets with first matching supported token, when screen get loaded.
    // to avoid this we use flag, for selected token validation. `if it contains in from tokens in SwapQuote`
    private var isInitialServerValidation: Bool = true
    private var errorSubject: PassthroughSubject<TokenSwapper.TokenSwapperError?, Never> = .init()
    private var cancelable = Set<AnyCancellable>()
    private let tokenCollection: TokenCollection
    private var fromAmountSubject: CurrentValueSubject<BigInt?, Never> = .init(nil)
    private var fetchSwapQuoteStateSubject: CurrentValueSubject<SwapQuoteState, Never> = .init(.pendingInput)
    @Published private(set) var sessions: [WalletSession]
    @Published private(set) var server: RPCServer
    @Published private(set) var swapPair: SwapPair
    private (set) var lastSwapQuote: SwapQuote?

    var fromAmount: BigUInt? {
        fromAmountSubject.value.flatMap({ BigUInt($0) })
    }

    var activeValidServer: RPCServer {
        swapPair.from.server
    }

    var fetchSwapQuoteState: AnyPublisher<SwapQuoteState, Never> {
        fetchSwapQuoteStateSubject.removeDuplicates()
            .eraseToAnyPublisher()
    }

    var session: WalletSession {
        sessions.first(where: { $0.server == server })!
    }

    var slippage: CurrentValueSubject<SwapSlippage, Never> = .init(.tenPercents)

    private (set) lazy var fromAndToTokensPublisher: AnyPublisher<FromAndToTokens?, Never> = {
        return $swapPair.map { $0.asFromAndToTokens }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }()

    var error: AnyPublisher<TokenSwapper.TokenSwapperError?, Never> {
        errorSubject.eraseToAnyPublisher()
    }

    let tokenSwapper: TokenSwapper

    private (set) lazy var validatedAmount: AnyPublisher<BigUInt, Never> = {
        let hasFromAndToSwapTokens = fromAndToTokensPublisher
            .map { $0 != nil }

        return fromAmountSubject.combineLatest(hasFromAndToSwapTokens) { amount, hasSwapToken -> BigInt? in
            return hasSwapToken ? amount : nil
        }.compactMap { $0.flatMap { BigUInt($0) } }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }()

    private (set) lazy var swapQuote: AnyPublisher<SwapQuote?, Never> = {
        //NOTE: here we use debounce to reduce requests calls when user quickly switches beetwen tokens, or types amount to swap
        let amount = validatedAmount.debounce(for: .milliseconds(250), scheduler: RunLoop.main)
        let fromAndToTokens = fromAndToTokensPublisher.compactMap { $0 }

        let slippage = slippage.map { String($0.doubleValue).droppedTrailingZeros }
            .eraseToAnyPublisher()

        return Publishers.CombineLatest3(amount, fromAndToTokens, slippage)
            .compactMap { [weak self] (amount, tokens, slippage) -> AnyPublisher<SwapQuote?, Never>? in
                if amount == .zero {
                    return Just<SwapQuote?>(nil).eraseToAnyPublisher()
                } else {
                    return self?.fetchSwapQuote(tokens: tokens, amount: amount, slippage: slippage)
                }
            }.switchToLatest()
            .share()
            .prepend(nil)
            .eraseToAnyPublisher()
    }()

    init(sessionProvider: SessionsProvider, swapPair: SwapPair, tokenCollection: TokenCollection, reachabilityManager: ReachabilityManagerProtocol, tokenSwapper: TokenSwapper) {
        self.tokenSwapper = tokenSwapper
        self.sessions = sessionProvider.activeSessions.values.sorted(by: { $0.server.displayOrderPriority < $1.server.displayOrderPriority })
        self.server = swapPair.from.server
        self.swapPair = swapPair
        self.tokenCollection = tokenCollection

        invalidateSessionsWhenSupportedTokensChanged()
        fetchSupportedTokensForSelectedServer()
        resetToTokenForNonSupportedSwapPair()
    } 

    func set(token: Token, selection: SwapTokens.TokenSelection) {
        var pair = swapPair
        switch selection {
        case .to: pair.to = token
        case .from: pair.from = token
        }
        swapPair = pair
    }

    func set(fromToken token: Token) {
        var pair = swapPair
        pair.from = token
        swapPair = pair
    }

    func togglePair() {
        guard let toToken = swapPair.to else { return }
        swapPair = SwapPair(from: toToken, to: swapPair.from)
    }

    func swapPairs(for server: RPCServer) -> SwapPairs? {
        return tokenSwapper.swapPairs(for: server)
    }

    func start() {
        tokenSwapper.reload()
    }

    func set(fromAmount amount: BigInt?) {
        fromAmountSubject.value = amount
    }

    func set(server: RPCServer) {
        self.server = server
    }

    func isAvailable(server: RPCServer) -> Bool {
        switch tokenSwapper.supportState(for: server) {
        case .supports:
            return hasAnySuportedToken(forServer: server)
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

    private func fetchSwapQuote(tokens: FromAndToTokens, amount: BigUInt, slippage: String) -> AnyPublisher<SwapQuote?, Never> {
        let wallet = session.account.address
        fetchSwapQuoteStateSubject.send(.fetching)

        return Just(tokens)
            .flatMapLatest { [tokenSwapper] tokens in
                tokenSwapper.fetchSwapQuote(fromToken: tokens.from, toToken: tokens.to, wallet: wallet, slippage: slippage, fromAmount: amount)
            }.handleEvents(receiveOutput: { [weak fetchSwapQuoteStateSubject, weak errorSubject, weak self] result in
                switch result {
                case .success(let swapQuote):
                    self?.set(swapQuote: swapQuote)
                    fetchSwapQuoteStateSubject?.send(.completed(error: nil))
                case .failure(let error):
                    fetchSwapQuoteStateSubject?.send(.completed(error: error))
                    errorSubject?.send(.general(error: error))
                }
            }).map { result -> SwapQuote? in
                switch result {
                case .success(let swapQuote): return swapQuote
                case .failure: return nil
                }
            }.eraseToAnyPublisher()
    }

    private func set(swapQuote: SwapQuote) {
        lastSwapQuote = swapQuote
    }

    private func validateSwapPair(forServer server: RPCServer, isInitialServerValidation: Bool) {
        do {
            let tokens = try supportedTokens(forServer: server)
            let token = try firstSupportedFromToken(forServer: server, tokens: tokens)
            if isInitialServerValidation && !swapPair.from.contractAddress.sameContract(as: token.contractAddress) {
                let _ = try firstSupportedFromToken(forServer: server, tokens: [swapPair.from])
                //NOTE: no changes needed as current swapPair.from supports
            } else {
                swapPair = SwapPair(from: token, to: nil)
            }
        } catch TokenSwapper.TokenSwapperError.fromTokenNotFound {
            errorSubject.send(.fromTokenNotFound)
        } catch { }
    }

    private func hasAnySuportedToken(forServer server: RPCServer) -> Bool {
        guard let tokens = try? supportedTokens(forServer: server) else { return false }
        let token = try? firstSupportedFromToken(forServer: server, tokens: tokens)
        return token != nil
    }

    private func supportedTokens(forServer server: RPCServer) throws -> [Token] {
        guard swapPairs(for: server) != nil else { throw TokenSwapper.TokenSwapperError.swapPairNotFound }
        return tokenCollection.tokens(for: [server])
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
