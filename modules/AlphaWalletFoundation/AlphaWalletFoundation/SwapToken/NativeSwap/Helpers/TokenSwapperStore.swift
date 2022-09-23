//
//  TokenSwapperStore.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.05.2022.
//

import Foundation
import Combine
import AlphaWalletCore

public protocol SwapQuoteStorage {
    var swapQuote: SwapQuote? { get }
    mutating func set(swapQuote: SwapQuote)
}

public protocol SwapRouteStorage {
    var prefferedExchange: AnyPublisher<String?, Never> { get }
    var swapRoutes: AnyPublisher<[SwapRoute], Never> { get }

    func isPreffered(_ swapRoute: SwapRoute) -> Bool
    func swapRoute(at index: Int) -> SwapRoute?
    mutating func set(prefferedSwapRoute: SwapRoute)
    mutating func addOrUpdate(swapRoutes: [SwapRoute])
    mutating func invalidatePrefferedSwapRoute()
}

public protocol SwapSupportStateStorage {
    var supportedServers: AnyPublisher<[SwapSupportState], Never> { get }

    mutating func addOrUpdate(swapSupportStates: [SwapSupportState])
    func supportState(for server: RPCServer) -> SwapSupportState
    func swapPairs(for server: RPCServer) -> SwapPairs?
}

public protocol SwapPairsStorage {
    var supportedTokens: AnyPublisher<[RPCServer: SwapPairs], Never> { get }

    mutating func addOrUpdate(swapPairs: SwapPairs, for server: RPCServer)
    func containsSwapPairs(for server: RPCServer) -> Bool
}

public protocol SwapToolStorage {
    var selectedTools: AnyPublisher<[SwapTool], Never> { get }
    var allSupportedTools: AnyPublisher<[SwapTool], Never> { get }

    func swapTool(at index: Int) -> SwapTool?
    mutating func addOrUpdate(tools: [SwapTool])
    mutating func addOrUpdate(selectedTools: [SwapTool])
}

public struct InMemoryTokenSwapperStorage: SwapSupportStateStorage, SwapPairsStorage, SwapToolStorage, SwapRouteStorage, SwapQuoteStorage {
    private var supportedServersSubject: CurrentValueSubject<[SwapSupportState], Never> = .init([])
    private var supportedTokensSubject: CurrentValueSubject<[RPCServer: SwapPairs], Never> = .init([:])
    private var selectedToolsSubject: CurrentValueSubject<[SwapTool], Never> = .init([])
    private var allSupportedToolsSubject: CurrentValueSubject<[SwapTool], Never> = .init([])
    private var swapRoutesSubject: CurrentValueSubject<[SwapRoute], Never> = .init([])
    private var prefferedSwapRouteSubject: CurrentValueSubject<SwapRoute?, Never> = .init(nil)
    private (set) public var swapQuote: SwapQuote?
    public var supportedServers: AnyPublisher<[SwapSupportState], Never> {
        supportedServersSubject.eraseToAnyPublisher()
    }

    public mutating func addOrUpdate(swapSupportStates: [SwapSupportState]) {
        supportedServersSubject.value = swapSupportStates
    }

    public func supportState(for server: RPCServer) -> SwapSupportState {
        switch supportedServersSubject.value.first(where: { $0.server == server }) {
        case .some(let value):
            return value
        case .none:
            return .init(server: server, supportingType: .notSupports)
        }
    }

    public func swapPairs(for server: RPCServer) -> SwapPairs? {
        return supportedTokensSubject.value[server]
    }

    public var supportedTokens: AnyPublisher<[RPCServer: SwapPairs], Never> {
        supportedTokensSubject.eraseToAnyPublisher()
    }

    public mutating func addOrUpdate(swapPairs: SwapPairs, for server: RPCServer) {
        supportedTokensSubject.value[server] = swapPairs
    }

    public func containsSwapPairs(for server: RPCServer) -> Bool {
        swapPairs(for: server) != nil
    }

    public var selectedTools: AnyPublisher<[SwapTool], Never> {
        selectedToolsSubject.eraseToAnyPublisher()
    }

    public var allSupportedTools: AnyPublisher<[SwapTool], Never> {
        allSupportedToolsSubject.eraseToAnyPublisher()
    }

    public func swapTool(at index: Int) -> SwapTool? {
        allSupportedToolsSubject.value[safe: index]
    }

    public mutating func addOrUpdate(selectedTools: [SwapTool]) {
        selectedToolsSubject.value = selectedTools
    }

    public mutating func addOrUpdate(tools: [SwapTool]) {
        selectedToolsSubject.value = tools
        allSupportedToolsSubject.value = tools
    }

    public var prefferedExchange: AnyPublisher<String?, Never> {
        return prefferedSwapRouteSubject
            .map { $0.flatMap { TokenSwapper.firstExchange(from: $0) } }
            .eraseToAnyPublisher()
    }

    public var swapRoutes: AnyPublisher<[SwapRoute], Never> {
        return swapRoutesSubject.eraseToAnyPublisher()
    }

    public mutating func set(prefferedSwapRoute: SwapRoute) {
        prefferedSwapRouteSubject.send(prefferedSwapRoute)
    }

    public mutating func addOrUpdate(swapRoutes: [SwapRoute]) {
        swapRoutesSubject.value = swapRoutes
    }

    public func swapRoute(at index: Int) -> SwapRoute? {
        return swapRoutesSubject.value[safe: index]
    }

    public func isPreffered(_ swapRoute: SwapRoute) -> Bool {
        return prefferedSwapRouteSubject.value?.id == swapRoute.id
    }

    mutating public func set(swapQuote: SwapQuote) {
        self.swapQuote = swapQuote
    }

    mutating public func invalidatePrefferedSwapRoute() {
        prefferedSwapRouteSubject.send(.none)
        
        addOrUpdate(swapRoutes: [])
    }
}
