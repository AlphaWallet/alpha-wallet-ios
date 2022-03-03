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

    func autoDetectTransactedErc20AndNonErc20Tokens(wallet: AlphaWallet.Address) -> Promise<Void>
}

class AutoDetectTransactedTokensOperation: Operation {
    
    private let wallet: AlphaWallet.Address

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

    init(forServer server: RPCServer, delegate: AutoDetectTransactedTokensOperationDelegate, wallet: AlphaWallet.Address) {
        self.delegate = delegate
        self.wallet = wallet
        super.init()
        self.queuePriority = server.networkRequestsQueuePriority
    } 

    override func main() {
        guard let delegate = delegate else { return }

        delegate.autoDetectTransactedErc20AndNonErc20Tokens(wallet: wallet).done { [weak self] _ in
            guard let strongSelf = self else { return }

            strongSelf.willChangeValue(forKey: "isExecuting")
            strongSelf.willChangeValue(forKey: "isFinished")
            delegate.isAutoDetectingTransactedTokens = false
            strongSelf.didChangeValue(forKey: "isExecuting")
            strongSelf.didChangeValue(forKey: "isFinished")
        }.cauterize()
    }
}
