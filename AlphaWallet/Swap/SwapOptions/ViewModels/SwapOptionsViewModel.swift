//
//  SwapOptionsViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import Foundation
import Combine
import UIKit
import AlphaWalletFoundation

struct SwapOptionsViewModelInput { }

struct SwapOptionsViewModelOutput {
    let viewState: AnyPublisher<SwapOptionsViewModel.ViewState, Never>
    let errorString: AnyPublisher<String, Never>
}

class SwapOptionsViewModel {
    private let configurator: SwapOptionsConfigurator
    private var cancelable = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "org.alphawallet.swift.swapOptions.processingQueue", qos: .utility)
    private var anyError: AnyPublisher<TokenSwapper.TokenSwapperError, Never> {
        configurator.error
            .compactMap { $0 }
            .filter { $0 == .swapPairNotFound || $0 == .sessionsEmpty || $0 == .fromTokenNotFound }
            .eraseToAnyPublisher()
    }

    var navigationTitle: String = "Settings"
    var sessions: [WalletSession] {
        configurator.sessions
    }
    let slippageViewModel: SlippageViewModel

    init(configurator: SwapOptionsConfigurator) {
        self.configurator = configurator
        slippageViewModel = .init(selectedSlippage: configurator.slippage)
    }

    func transform(input: SwapOptionsViewModelInput) -> SwapOptionsViewModelOutput {
        anyError.sink { [weak self, configurator] _ in
            self?.set(selectedServer: configurator.activeValidServer)
        }.store(in: &cancelable)

        let sessions = Publishers.CombineLatest(configurator.$sessions, configurator.$server)
                .receive(on: queue)
                .map { [weak configurator] sessions, server -> [ServerImageViewModel] in
                    guard let configurator = configurator else { return [] }
                    return sessions.map {
                        let isAvailableToSelect = configurator.isAvailable(server: $0.server)
                        return ServerImageViewModel(server: .server($0.server), selected: $0.server == server, isAvailableToSelect: isAvailableToSelect)
                    }
                }.map { sessions -> SwapOptionsViewModel.SessionsSnapshot in
                    var snapshot = SwapOptionsViewModel.SessionsSnapshot()
                    snapshot.appendSections([.sessions])
                    snapshot.appendItems(sessions)

                    return snapshot
                }.receive(on: RunLoop.main)
                .eraseToAnyPublisher()

        let errorString = anyError
            .map { $0.description }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()

        let viewState = sessions.map { SwapOptionsViewModel.ViewState(sessions: $0) }
            .eraseToAnyPublisher()

        return .init(viewState: viewState, errorString: errorString)
    }

    func set(selectedServer server: RPCServer) {
        guard configurator.isAvailable(server: server) else { return }
        configurator.set(server: server)
    }
}

extension SwapOptionsViewModel {
    class SessionsDiffableDataSource: UITableViewDiffableDataSource<SwapOptionsViewModel.Section, ServerImageViewModel> {}
    typealias SessionsSnapshot = NSDiffableDataSourceSnapshot<SwapOptionsViewModel.Section, ServerImageViewModel>

    enum Section: Int, Hashable {
        case sessions
    }

    struct ViewState {
        let sessions: SessionsSnapshot
    }
}
