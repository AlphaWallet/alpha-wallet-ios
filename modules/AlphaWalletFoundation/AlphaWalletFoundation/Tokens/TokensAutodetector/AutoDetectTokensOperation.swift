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
    private var cancelable = Set<AnyCancellable>()

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

    init(session: WalletSession, delegate: AutoDetectTokensOperationDelegate, tokens: [ContractToImport]) {
        self.delegate = delegate
        self.tokens = tokens
        super.init()
        self.queuePriority = session.server.networkRequestsQueuePriority
    } 

    override func main() {
        guard let delegate = delegate else { return }

        delegate.autoDetectTokensImpl(withContracts: tokens)
            .sink(receiveCompletion: { _ in

            }, receiveValue: { values in

                self.willChangeValue(forKey: "isExecuting")
                self.willChangeValue(forKey: "isFinished")
                delegate.isAutoDetectingTokens = false
                self.didChangeValue(forKey: "isExecuting")
                self.didChangeValue(forKey: "isFinished")

                guard !self.isCancelled else { return }
                self.delegate?.didDetect(tokensOrContracts: values)
            }).store(in: &cancelable)
    } 
}
