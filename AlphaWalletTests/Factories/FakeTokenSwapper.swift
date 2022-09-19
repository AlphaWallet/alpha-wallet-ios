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
    private let subject: CurrentValueSubject<Bool, Never>

    var isReachable: Bool { subject.value }
    var isReachablePublisher: AnyPublisher<Bool, Never> { subject.eraseToAnyPublisher() }
    var networkBecomeReachablePublisher: AnyPublisher<Void, Never> { subject.mapToVoid().eraseToAnyPublisher() }

    init(_ value: Bool) {
        subject = .init(value)
    }

    func set(isReachable value: Bool) {
        subject.value = value
    }
}

final class FakeTokenSwapper: TokenSwapper {
    convenience init(sessionProvider: SessionsProvider = .make(wallet: .make(), servers: [.main])) {
        self.init(reachabilityManager: FakeReachabilityManager(true), sessionProvider: sessionProvider, networkProvider: FakeTokenSwapperNetworkProvider())
    }
}
