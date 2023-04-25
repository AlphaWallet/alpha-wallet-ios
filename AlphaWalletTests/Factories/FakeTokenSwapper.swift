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

    var isReachable: Bool {
        get { subject.value }
        set { subject.value = newValue }
    }
    var isReachablePublisher: AnyPublisher<Bool, Never> { subject.eraseToAnyPublisher() }
    var networkBecomeReachablePublisher: AnyPublisher<Void, Never> { subject.mapToVoid().eraseToAnyPublisher() }

    init(_ value: Bool) {
        subject = .init(value)
    }
}

extension TokenSwapper {
    static func make(enabledServers: [RPCServer] = [.main]) -> TokenSwapper {
        return TokenSwapper(
            reachabilityManager: FakeReachabilityManager(true),
            serversProvider: BaseServersProvider(config: .make(enabledServers: enabledServers)),
            networking: FakeTokenSwapperNetworking(),
            analyticsLogger: FakeAnalyticsService()
        )
    }
}
