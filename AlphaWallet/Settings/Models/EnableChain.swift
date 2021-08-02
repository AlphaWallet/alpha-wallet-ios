// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import APIKit
import JSONRPCKit
import PromiseKit

protocol EnableChainDelegate: AnyObject {
    func notifyEnableChainQueuedSuccessfully(in enableChain: EnableChain)

}

class EnableChain {
    private let server: RPCServer
    private let restartQueue: RestartTaskQueue
    private let url: URL?

    weak var delegate: EnableChainDelegate?

    init(_ server: RPCServer, restartQueue: RestartTaskQueue, url: URL?) {
        self.server = server
        self.restartQueue = restartQueue
        self.url = url
    }

    func run() {
        restartQueue.add(.enableServer(server))
        restartQueue.add(.switchDappServer(server: server))
        if let url = url {
            restartQueue.add(.loadUrlInDappBrowser(url))
        }
        delegate?.notifyEnableChainQueuedSuccessfully(in: self)
    }
}