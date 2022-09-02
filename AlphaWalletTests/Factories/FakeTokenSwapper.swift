//
//  FakeTokenSwapper.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

@testable import AlphaWallet
import Combine
import AlphaWalletFoundation

final class FakeReachabilityManager: ReachabilityManagerProtocol {
    var isReachable: Bool { return true }

    var isReachablePublisher: AnyPublisher<Bool, Never> {
        return Just<Bool>(true).eraseToAnyPublisher()
    }

    var networkBecomeReachablePublisher: AnyPublisher<Void, Never> {
        return Just<Void>(()).eraseToAnyPublisher()
    }
}

final class FakeTokenSwapper: TokenSwapper {
    convenience init(sessionProvider: SessionsProvider = .make(wallet: .make(), servers: [.main])) {
        self.init(reachabilityManager: FakeReachabilityManager(), sessionProvider: sessionProvider, networkProvider: FakeTokenSwapperNetworkProvider())
    }
}
