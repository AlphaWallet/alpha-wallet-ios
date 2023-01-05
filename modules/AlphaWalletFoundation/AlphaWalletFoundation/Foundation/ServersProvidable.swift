//
//  ServersProvidable.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 05.01.2023.
//

import Foundation
import Combine

public protocol ServersProvidable {
    var servers: AnyPublisher<Set<RPCServer>, Never> { get }
}

public class BaseServersProvider: ServersProvidable {
    private let config: Config

    public var servers: AnyPublisher<Set<RPCServer>, Never> {
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
