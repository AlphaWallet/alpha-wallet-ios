//
//  TokensAutodetector.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.02.2022.
//

import Foundation
import AlphaWalletCore
import Combine

public enum EipTokenType: String {
    case erc20
    case erc721
    case erc1155
}

public protocol TokensAutodetector {
    var detectedTokensOrContracts: AnyPublisher<[TokenOrContract], Never> { get }

    func start() async
    func stop()
    func resume()
}

public actor SingleChainTokensAutodetector: NSObject, TokensAutodetector {
    private var cancellable = Set<AnyCancellable>()
    private let autodetectors: [TokensAutodetector]
    private let subject = PassthroughSubject<[TokenOrContract], Never>()

    public nonisolated var detectedTokensOrContracts: AnyPublisher<[TokenOrContract], Never> {
        subject.eraseToAnyPublisher()
    }

    init(autodetectors: [TokensAutodetector]) {
        self.autodetectors = autodetectors

        let publishers = autodetectors.map { $0.detectedTokensOrContracts }
        Publishers.MergeMany(publishers)
            .multicast(subject: subject)
            .connect()
            .store(in: &cancellable)

        super.init()

        NotificationCenter.default.applicationState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                switch state {
                case .didEnterBackground:
                    self?.stop()
                case .willEnterForeground:
                    self?.resume()
                }
            }.store(in: &cancellable)
    }

    public nonisolated func start() async {
        for each in autodetectors {
            await each.start()
        }
    }

    public nonisolated func stop() {
        autodetectors.forEach { $0.stop() }
    }

    public nonisolated func resume() {
        autodetectors.forEach { $0.resume() }
    }
}
