//
//  SwapOptionsViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import Foundation
import Combine

struct SwapOptionsViewModelInput { }

struct SwapOptionsViewModelOutput {
    let sessions: AnyPublisher<[SelectNetworkViewModel], Never>
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
                .map { [weak configurator] sessions, server -> [SelectNetworkViewModel] in
                    guard let configurator = configurator else { return [] }
                    return sessions.map {
                        let isAvailableToSelect = configurator.isAvailable(server: $0.server)
                        return SelectNetworkViewModel(session: $0, isSelected: $0.server == server, isAvailableToSelect: isAvailableToSelect)
                    }
                }.receive(on: RunLoop.main)
                .eraseToAnyPublisher()

        let errorString = anyError
            .map { $0.description }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()

        return .init(sessions: sessions, errorString: errorString)
    }

    func set(selectedServer server: RPCServer) {
        configurator.set(server: server)
    }
}
