//
//  FakeTokenSwapper.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

@testable import AlphaWallet
import Combine

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
    convenience init(sessions: AnyPublisher<ServerDictionary<WalletSession>, Never> = sessions(server: .main).eraseToAnyPublisher()) {
        self.init(reachabilityManager: FakeReachabilityManager(), sessions: sessions, networkProvider: FakeTokenSwapperNetworkProvider())
    }
}
