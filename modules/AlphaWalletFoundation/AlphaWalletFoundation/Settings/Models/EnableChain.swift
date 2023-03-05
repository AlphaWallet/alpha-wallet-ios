// Copyright © 2021 Stormbird PTE. LTD.

import Foundation

public protocol EnableChainDelegate: AnyObject {
    func notifyEnableChainQueuedSuccessfully(in enableChain: EnableChain)
}

public class EnableChain {
    private let server: RPCServer
    private let restartHandler: RestartQueueHandler
    private let url: URL?

    public weak var delegate: EnableChainDelegate?

    public init(_ server: RPCServer, restartHandler: RestartQueueHandler, url: URL?) {
        self.server = server
        self.restartHandler = restartHandler
        self.url = url
    }

    public func run() {
        restartHandler.add(.enableServer(server))
        restartHandler.add(.switchDappServer(server: server))
        if let url = url {
            restartHandler.add(.loadUrlInDappBrowser(url))
        }
        delegate?.notifyEnableChainQueuedSuccessfully(in: self)
    }
}
