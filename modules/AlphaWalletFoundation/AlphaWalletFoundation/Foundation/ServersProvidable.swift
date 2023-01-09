//
//  ServersProvidable.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 05.01.2023.
//

import Foundation
import Combine

public protocol ServersProvidable: AnyObject {
    var allServers: [RPCServer] { get }
    var enabledServersPublisher: AnyPublisher<Set<RPCServer>, Never> { get }
    var enabledServers: [RPCServer] { get set }
    var anyEnabledServer: RPCServer { get }
    var browserRpcServer: RPCServer { get set }
}

public class BaseServersProvider: ServersProvidable {
    private var config: Config

    public var allServers: [RPCServer] {
        RPCServer.allCases
    }

    public var enabledServers: [RPCServer] {
        get { return config.enabledServers }
        set { config.enabledServers = newValue }
    }

    public var browserRpcServer: RPCServer {
        get {
            if enabledServers.contains(browserRpcServerUnverified) {
                return browserRpcServerUnverified
            } else {
                let fallback = enabledServers[0]
                Config.setChainId(fallback.chainID)
                return fallback
            }
        }
        set {
            Config.setChainId(newValue.chainID)
        }
    }

    private var browserRpcServerUnverified: RPCServer {
        RPCServer(chainID: Config.getChainId())
    }

    public var anyEnabledServer: RPCServer {
        let servers = enabledServers
        if servers.contains(.main) {
            return .main
        } else {
            return servers.first!
        }
    }

    public var enabledServersPublisher: AnyPublisher<Set<RPCServer>, Never> {
        Just(config.enabledServers)
            .merge(with: config.enabledServersPublisher)//subscribe for servers changing so not active providers can handle changes too
            .removeDuplicates()
            .filter { !$0.isEmpty }
            .compactMap { Set($0) }
            .eraseToAnyPublisher()
    }

    public init(config: Config = .init()) {
        self.config = config
    }
}
