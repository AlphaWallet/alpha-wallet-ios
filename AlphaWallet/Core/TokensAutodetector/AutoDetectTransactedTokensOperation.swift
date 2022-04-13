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

    func autoDetectTransactedErc20AndNonErc20Tokens(wallet: AlphaWallet.Address) -> Promise<[SingleChainTokensAutodetector.AddTokenObjectOperation]>
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
    private let tokensDataStore: TokensDataStore

    init(session: WalletSession, tokensDataStore: TokensDataStore, delegate: AutoDetectTransactedTokensOperationDelegate) {
        self.delegate = delegate
        self.session = session
        self.tokensDataStore = tokensDataStore
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
            strongSelf.tokensDataStore.addTokenObjects(values: values)
        }.cauterize()
    }
}
