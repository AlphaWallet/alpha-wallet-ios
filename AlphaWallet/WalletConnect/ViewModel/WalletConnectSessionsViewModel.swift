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

struct WalletConnectSessionsViewModelInput {

}

struct WalletConnectSessionsViewModelIOutput {
    let viewState: AnyPublisher<WalletConnectSessionsViewModel.ViewState, Never>
}

class WalletConnectSessionsViewModel {
    private let provider: WalletConnectServerProviderType
    private var cancelable = Set<AnyCancellable>()
    private let stateSubject: CurrentValueSubject<State, Never>

    init(provider: WalletConnectServerProviderType, state: State = .sessions) {
        self.provider = provider
        self.stateSubject = .init(state)
    }

    func transform(input: WalletConnectSessionsViewModelInput) -> WalletConnectSessionsViewModelIOutput {
        let snapshot = provider.sessions
            .map { sessions -> Snapshot in
                var snapshot = Snapshot()
                snapshot.appendSections([.sessions])
                snapshot.appendItems(sessions)

                return snapshot
            }

        let viewState = Publishers.CombineLatest(stateSubject, snapshot)
            .map { state, snapshot -> ViewState in
                ViewState(title: R.string.localizable.walletConnectTitle(), state: state, snapshot: snapshot)
            }.receive(on: RunLoop.main)
            .eraseToAnyPublisher()

        return .init(viewState: viewState)
    }

    func set(state: State) {
        stateSubject.send(state)
    }

    func hasAnyContent(_ dataSource: WalletConnectSessionsViewModel.DataSource) -> Bool {
        switch stateSubject.value {
        case .sessions:
            return dataSource.snapshot().numberOfItems != 0
        case .waitingForSessionConnection:
            return true
        }
    }
}

extension WalletConnectSessionsViewModel {
    class DataSource: UITableViewDiffableDataSource<WalletConnectSessionsViewModel.Section, AlphaWallet.WalletConnect.Session> {}
    typealias Snapshot = NSDiffableDataSourceSnapshot<WalletConnectSessionsViewModel.Section, AlphaWallet.WalletConnect.Session>

    enum State {
        case sessions
        case waitingForSessionConnection
    }

    enum Section: Int, Hashable, CaseIterable {
        case sessions
    }

    struct ViewState {
        let title: String
        let state: WalletConnectSessionsViewModel.State
        let snapshot: WalletConnectSessionsViewModel.Snapshot
        let animatingDifferences: Bool = false
    }
}
