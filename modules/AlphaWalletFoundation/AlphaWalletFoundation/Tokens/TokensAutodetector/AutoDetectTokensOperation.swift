//
//  AutoDetectTokensOperation.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.02.2022.
//

import Foundation
import Combine

protocol AutoDetectTokensOperationDelegate: AnyObject {
    var isAutoDetectingTokens: Bool { get set }

    func didDetect(tokensOrContracts: [TokenOrContract])
    func autoDetectTokensImpl(withContracts contractsToDetect: [ContractToImport]) -> AnyPublisher<[TokenOrContract], Never>
}

final class AutoDetectTokensOperation: Operation {
    private let tokens: [ContractToImport]
    private var cancellable: AnyCancellable?

    weak private var delegate: AutoDetectTokensOperationDelegate?
    override var isExecuting: Bool {
        return delegate?.isAutoDetectingTokens ?? false
    }
    override var isFinished: Bool {
        return !isExecuting
    }
    override var isAsynchronous: Bool {
        return true
    }

    init(server: RPCServer, delegate: AutoDetectTokensOperationDelegate, tokens: [ContractToImport]) {
        self.delegate = delegate
        self.tokens = tokens
        super.init()
        self.queuePriority = server.networkRequestsQueuePriority
    }

    override func cancel() {
        cancellable?.cancel()
        cancellable = nil
    }

    override func main() {
        guard let delegate = delegate else { return }

        cancellable = delegate.autoDetectTokensImpl(withContracts: tokens)
            .sink(receiveCompletion: { _ in

            }, receiveValue: { [weak self] values in

                self?.willChangeValue(forKey: "isExecuting")
                self?.willChangeValue(forKey: "isFinished")
                delegate.isAutoDetectingTokens = false
                self?.didChangeValue(forKey: "isExecuting")
                self?.didChangeValue(forKey: "isFinished")

                self?.delegate?.didDetect(tokensOrContracts: values)
            })
    } 
}
