// Copyright © 2021 Stormbird PTE. LTD.

import Foundation

public protocol EnableChainDelegate: AnyObject {
    func notifyEnableChainQueuedSuccessfully(in enableChain: EnableChain)
}

public class EnableChain {
    private let server: RPCServer
    private let restartQueue: RestartTaskQueue
    private let url: URL?

    public weak var delegate: EnableChainDelegate?

    public init(_ server: RPCServer, restartQueue: RestartTaskQueue, url: URL?) {
        self.server = server
        self.restartQueue = restartQueue
        self.url = url
    }

    public func run() {
        restartQueue.add(.enableServer(server))
        restartQueue.add(.switchDappServer(server: server))
        if let url = url {
            restartQueue.add(.loadUrlInDappBrowser(url))
        }
        delegate?.notifyEnableChainQueuedSuccessfully(in: self)
    }
}
