//
//  WalletConnectSessionsViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.04.2022.
//

import Foundation
import Combine
import UIKit
import AlphaWalletFoundation

class WalletConnectSessionsDiffableDataSource: UITableViewDiffableDataSource<WalletConnectSessionsViewModel.Section, AlphaWallet.WalletConnect.Session> {}
typealias WalletConnectSessionsSnapshot = NSDiffableDataSourceSnapshot<WalletConnectSessionsViewModel.Section, AlphaWallet.WalletConnect.Session>

class WalletConnectSessionsViewModel {
    enum State {
        case sessions
        case waitingForSessionConnection
    }

    enum Section: Int, Hashable, CaseIterable {
        case sessions
    }

    private let provider: WalletConnectServerProviderType
    private var cancelable = Set<AnyCancellable>()
    var state: State { stateSubject.value }
    let stateSubject: CurrentValueSubject<State, Never>
    var natigationTitle: String = R.string.localizable.walletConnectTitle()
    var sessionsSnapshot: AnyPublisher<WalletConnectSessionsSnapshot, Never> {
        provider.sessions.map {
            var snapshot = NSDiffableDataSourceSnapshot<WalletConnectSessionsViewModel.Section, AlphaWallet.WalletConnect.Session>()
            snapshot.appendSections([.sessions])
            snapshot.appendItems($0)

            return snapshot
        }.eraseToAnyPublisher()
    }

    init(provider: WalletConnectServerProviderType, state: State = .sessions) {
        self.provider = provider
        self.stateSubject = .init(state)
    }

    func set(state: State) {
        stateSubject.send(state)
    }

    func hasAnyContent(_ dataSource: WalletConnectSessionsDiffableDataSource) -> Bool {
        switch state {
        case .sessions:
            return dataSource.snapshot().numberOfItems != 0
        case .waitingForSessionConnection:
            return true
        }
    }
}
