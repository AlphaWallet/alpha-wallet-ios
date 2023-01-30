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
    private var cancellable: AnyCancellable?
    private let wallet: Wallet
    
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

    init(server: RPCServer, wallet: Wallet, delegate: AutoDetectTransactedTokensOperationDelegate) {
        self.delegate = delegate
        self.wallet = wallet
        super.init()
        self.queuePriority = server.networkRequestsQueuePriority
    }

    override func cancel() {
        cancellable?.cancel()
        cancellable = nil
    }

    override func main() {
        guard let delegate = delegate else { return }

        cancellable = delegate.autoDetectTransactedErc20AndNonErc20Tokens(wallet: wallet.address)
            .sink(receiveCompletion: { _ in

            }, receiveValue: { [weak self] values in
                self?.willChangeValue(forKey: "isExecuting")
                self?.willChangeValue(forKey: "isFinished")
                delegate.isAutoDetectingTransactedTokens = false
                self?.didChangeValue(forKey: "isExecuting")
                self?.didChangeValue(forKey: "isFinished")

                self?.delegate?.didDetect(tokensOrContracts: values)
            })
    }
}
