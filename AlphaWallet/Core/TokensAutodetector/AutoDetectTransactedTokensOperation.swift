//
//  AutoDetectTransactedTokensOperation.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.02.2022.
//

import Foundation
import PromiseKit

protocol AutoDetectTransactedTokensOperationDelegate: class {
    var isAutoDetectingTransactedTokens: Bool { get set }

    func didDetect(tokensOrContracts: [TokenOrContract])
    func autoDetectTransactedErc20AndNonErc20Tokens(wallet: AlphaWallet.Address) -> Promise<[TokenOrContract]>
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

    private let session: WalletSession

    init(session: WalletSession, delegate: AutoDetectTransactedTokensOperationDelegate) {
        self.delegate = delegate
        self.session = session
        super.init()
        self.queuePriority = session.server.networkRequestsQueuePriority
    }

    override func main() {
        guard let delegate = delegate else { return }

        delegate.autoDetectTransactedErc20AndNonErc20Tokens(wallet: session.account.address).done { [weak self] values in
            guard let strongSelf = self else { return }

            strongSelf.willChangeValue(forKey: "isExecuting")
            strongSelf.willChangeValue(forKey: "isFinished")
            delegate.isAutoDetectingTransactedTokens = false
            strongSelf.didChangeValue(forKey: "isExecuting")
            strongSelf.didChangeValue(forKey: "isFinished")

            guard !strongSelf.isCancelled else { return }
            strongSelf.delegate?.didDetect(tokensOrContracts: values)
        }.catch { error in
            warnLog("Error while detecting tokens wallet: \(self.session.account.address.eip55String) error: \(error)")
        }
    }
}
