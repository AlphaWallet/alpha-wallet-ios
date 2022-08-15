//
//  SwapOptionsViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import Foundation
import Combine

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
    var slippageViewModel: SlippageViewModel
    var tansactionDeadalineViewModel: TransactionDeadlineTextFieldModel
    lazy var sessionsViewModels: AnyPublisher<[SelectNetworkViewModel], Never> = {
        return Publishers.CombineLatest(configurator.$sessions, configurator.$server)
            .receive(on: queue)
            .map { [weak configurator] sessions, server in
                guard let configurator = configurator else { return [] }
                return sessions.map {
                    let isAvailableToSelect = configurator.isSupported(server: $0.server)
                    return SelectNetworkViewModel(session: $0, isSelected: $0.server == server, isAvailableToSelect: isAvailableToSelect)
                }
            }.eraseToAnyPublisher()
    }()
    var errorString: AnyPublisher<String, Never> {
        anyError
            .map { $0.description }
            .eraseToAnyPublisher()
    }
    
    init(configurator: SwapOptionsConfigurator) {
        self.configurator = configurator
        slippageViewModel = .init(selectedSlippage: configurator.slippage)
        tansactionDeadalineViewModel = .init(value: configurator.transactionDeadline)

        anyError.sink { [weak self] _ in
            self?.set(selectedServer: configurator.activeValidServer)
        }.store(in: &cancelable)
    } 

    func set(selectedServer server: RPCServer) {
        configurator.set(server: server)
    }

    func set(tansactionDeadaline: Double) {
        configurator.set(transactionDeadline: tansactionDeadaline)
    }
}
