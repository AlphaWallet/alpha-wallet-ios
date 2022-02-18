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

    func autoDetectTokensImpl(withContracts contractsToDetect: [(name: String, contract: AlphaWallet.Address)], server: RPCServer) -> Promise<Void>
}

class AutoDetectTokensOperation: Operation {
    private let wallet: AlphaWallet.Address
    private let tokens: [(name: String, contract: AlphaWallet.Address)]
    private let server: RPCServer

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

    init(forServer server: RPCServer, delegate: AutoDetectTokensOperationDelegate, wallet: AlphaWallet.Address, tokens: [(name: String, contract: AlphaWallet.Address)]) {
        self.delegate = delegate
        self.wallet = wallet
        self.tokens = tokens
        self.server = server
        super.init()
        self.queuePriority = server.networkRequestsQueuePriority
    } 

    override func main() {
        guard let strongDelegate = delegate else { return }

        strongDelegate.autoDetectTokensImpl(withContracts: tokens, server: server).done { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.willChangeValue(forKey: "isExecuting")
            strongSelf.willChangeValue(forKey: "isFinished")
            strongDelegate.isAutoDetectingTokens = false
            strongSelf.didChangeValue(forKey: "isExecuting")
            strongSelf.didChangeValue(forKey: "isFinished")
        }.cauterize()
    }
}
