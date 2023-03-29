//
//  TokensAutodetector.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.02.2022.
//

import Foundation
import AlphaWalletCore
import Combine

public enum Eip20TokenType: String {
    case erc20
    case erc721
    case erc1155
}

public protocol TokensAutodetector {
    var detectedTokensOrContracts: AnyPublisher<[TokenOrContract], Never> { get }

    func start()
    func stop()
    func resume()
}

public class SingleChainTokensAutodetector: NSObject, TokensAutodetector {
    private var cancellable = Set<AnyCancellable>()
    private let autodetectors: [TokensAutodetector]
    private let subject = PassthroughSubject<[TokenOrContract], Never>()

    public var detectedTokensOrContracts: AnyPublisher<[TokenOrContract], Never> {
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

    public func start() {
        autodetectors.forEach { $0.start() }
    }

    public func stop() {
        autodetectors.forEach { $0.stop() }
    }

    public func resume() {
        autodetectors.forEach { $0.resume() }
    }
}
