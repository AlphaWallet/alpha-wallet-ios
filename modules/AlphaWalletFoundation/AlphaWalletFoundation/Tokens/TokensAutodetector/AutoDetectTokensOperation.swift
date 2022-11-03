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

    func didDetect(tokensOrContracts: [TokenOrContract])
    func autoDetectTokensImpl(withContracts contractsToDetect: [ContractToImport]) -> Promise<[TokenOrContract]>
}

final class AutoDetectTokensOperation: Operation {
    private let tokens: [ContractToImport]

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

    init(session: WalletSession, delegate: AutoDetectTokensOperationDelegate, tokens: [ContractToImport]) {
        self.delegate = delegate
        self.session = session
        self.tokens = tokens
        super.init()
        self.queuePriority = session.server.networkRequestsQueuePriority
    } 

    override func main() {
        guard let strongDelegate = delegate else { return }

        strongDelegate.autoDetectTokensImpl(withContracts: tokens).done { [weak self] values in
            guard let strongSelf = self else { return }

            strongSelf.willChangeValue(forKey: "isExecuting")
            strongSelf.willChangeValue(forKey: "isFinished")
            strongDelegate.isAutoDetectingTokens = false
            strongSelf.didChangeValue(forKey: "isExecuting")
            strongSelf.didChangeValue(forKey: "isFinished")

            guard !strongSelf.isCancelled else { return }
            strongSelf.delegate?.didDetect(tokensOrContracts: values)
        }.cauterize()
    } 
}
