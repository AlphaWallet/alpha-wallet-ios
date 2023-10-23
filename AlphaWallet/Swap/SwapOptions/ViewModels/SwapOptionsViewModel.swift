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
import AlphaWalletCore

struct SwapOptionsViewModelInput {
    let selection: AnyPublisher<IndexPath, Never>
}

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

    let slippageViewModel: SlippageViewModel
    lazy var selectedSwapToolsViewModel: SelectedSwapToolsCollectionViewModel = {
        SelectedSwapToolsCollectionViewModel(storage: configurator.tokenSwapper.storage)
    }()

    init(configurator: SwapOptionsConfigurator) {
        self.configurator = configurator
        slippageViewModel = .init(selectedSlippage: configurator.slippage)
    }

    func transform(input: SwapOptionsViewModelInput) -> SwapOptionsViewModelOutput {
        anyError.sink { [weak self, configurator] _ in
            self?.set(selectedServer: configurator.activeValidServer)
        }.store(in: &cancelable)

        input.selection
            .sink { [configurator] indexPath in
                let server = configurator.sessions[indexPath.row].server
                Task { @MainActor in
                    guard await configurator.isAvailable(server: server) else { return }
                    configurator.set(server: server)
                }
            }.store(in: &cancelable)

        let sessions = Publishers.CombineLatest(configurator.$sessions, configurator.$server)
                .receive(on: queue)
                .flatMap { [weak configurator] sessions, server in
                    asFuture {
                        guard let configurator = configurator else { return [] }
                        var models: [ServerImageViewModel] = []
                        for each in sessions {
                            let isAvailableToSelect = await configurator.isAvailable(server: each.server)
                            let model = ServerImageViewModel(server: .server(each.server), isSelected: each.server == server, isAvailableToSelect: isAvailableToSelect)
                            models.append(model)
                        }
                        return models
                    }
                }.map { (sessions: [ServerImageViewModel]) -> SwapOptionsViewModel.SessionsSnapshot in
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

        let viewState = sessions.map { SwapOptionsViewModel.ViewState(title: "Settings", sessions: $0) }
            .eraseToAnyPublisher()

        return .init(viewState: viewState, errorString: errorString)
    }

    func set(selectedServer server: RPCServer) {
        Task { @MainActor in
            guard await configurator.isAvailable(server: server) else { return }
            configurator.set(server: server)
        }
    }
}

extension SwapOptionsViewModel {
    class DataSource: UITableViewDiffableDataSource<SwapOptionsViewModel.Section, ServerImageViewModel> {}
    typealias SessionsSnapshot = NSDiffableDataSourceSnapshot<SwapOptionsViewModel.Section, ServerImageViewModel>

    enum Section: Int, Hashable {
        case sessions
    }

    struct ViewState {
        let title: String
        let sessions: SessionsSnapshot
    }
}
