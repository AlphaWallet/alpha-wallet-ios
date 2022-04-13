//
//  AutoDetectTokensOperation.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.02.2022.
//

import Foundation
import PromiseKit

protocol AutoDetectTokensOperationDelegate: class {
    var isAutoDetectingTokens: Bool { get set }

    func autoDetectTokensImpl(withContracts contractsToDetect: [(name: String, contract: AlphaWallet.Address)], server: RPCServer) -> Promise<[SingleChainTokensAutodetector.AddTokenObjectOperation]>
}

final class AutoDetectTokensOperation: Operation {
    private let tokens: [(name: String, contract: AlphaWallet.Address)]

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
    private let session: WalletSession
    private let tokensDataStore: TokensDataStore
    
    init(session: WalletSession, tokensDataStore: TokensDataStore, delegate: AutoDetectTokensOperationDelegate, tokens: [(name: String, contract: AlphaWallet.Address)]) {
        self.delegate = delegate
        self.session = session
        self.tokens = tokens
        self.tokensDataStore = tokensDataStore
        super.init()
        self.queuePriority = session.server.networkRequestsQueuePriority
    } 

    override func main() {
        guard let strongDelegate = delegate else { return }

        strongDelegate.autoDetectTokensImpl(withContracts: tokens, server: session.server).done { [weak self] values in
            guard let strongSelf = self else { return }

            strongSelf.willChangeValue(forKey: "isExecuting")
            strongSelf.willChangeValue(forKey: "isFinished")
            strongDelegate.isAutoDetectingTokens = false
            strongSelf.didChangeValue(forKey: "isExecuting")
            strongSelf.didChangeValue(forKey: "isFinished")

            guard !strongSelf.isCancelled else { return }
            strongSelf.tokensDataStore.addTokenObjects(values: values)
        }.cauterize()
    } 
}
