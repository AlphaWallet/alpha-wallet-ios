//
//  AutoDetectTransactedTokensOperation.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.02.2022.
//

import Foundation
import Combine

protocol AutoDetectTransactedTokensOperationDelegate: AnyObject {
    var isAutoDetectingTransactedTokens: Bool { get set }

    func didDetect(tokensOrContracts: [TokenOrContract])
    func autoDetectTransactedErc20AndNonErc20Tokens(wallet: AlphaWallet.Address) -> AnyPublisher<[TokenOrContract], Never>
}

final class AutoDetectTransactedTokensOperation: Operation {

    weak private var delegate: AutoDetectTransactedTokensOperationDelegate?
    override var isExecuting: Bool {
        return delegate?.isAutoDetectingTransactedTokens ?? false
    }
    override var isFinished: Bool {
        return !isExecuting
    }
    override var isAsynchronous: Bool {
        return true
    }
    private var cancelable = Set<AnyCancellable>()

    private let session: WalletSession

    init(session: WalletSession, delegate: AutoDetectTransactedTokensOperationDelegate) {
        self.delegate = delegate
        self.session = session
        super.init()
        self.queuePriority = session.server.networkRequestsQueuePriority
    }

    override func main() {
        guard let delegate = delegate else { return }

        delegate.autoDetectTransactedErc20AndNonErc20Tokens(wallet: session.account.address)
            .sink(receiveCompletion: { _ in

            }, receiveValue: { values in
                self.willChangeValue(forKey: "isExecuting")
                self.willChangeValue(forKey: "isFinished")
                delegate.isAutoDetectingTransactedTokens = false
                self.didChangeValue(forKey: "isExecuting")
                self.didChangeValue(forKey: "isFinished")

                guard !self.isCancelled else { return }
                self.delegate?.didDetect(tokensOrContracts: values)
            }).store(in: &cancelable)
    }
}
