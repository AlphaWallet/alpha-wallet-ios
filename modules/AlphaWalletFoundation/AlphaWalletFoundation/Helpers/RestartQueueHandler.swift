//
//  RestartQueueHandler.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.03.2022.
//

import Foundation

public protocol RestartQueueNavigatable: AnyObject {
    func openUrlInDappBrowser(url: URL, animated: Bool)
}

public final class RestartQueueHandler {
    private let restartQueue: RestartTaskQueue
    private let serversProvider: ServersProvidable

    public weak var navigation: RestartQueueNavigatable?

    public convenience init() {
        self.init(
            serversProvider: BaseServersProvider(),
            restartQueue: .init())
    }

    public init(serversProvider: ServersProvidable,
                restartQueue: RestartTaskQueue) {

        self.serversProvider = serversProvider
        self.restartQueue = restartQueue
    }

    public func add(_ task: RestartTaskQueue.Task) {
        restartQueue.add(task)
    }

    public func remove(_ task: RestartTaskQueue.Task) {
        restartQueue.remove(task)
    }

    public func processTasks() {
        for each in restartQueue.queue {
            switch each {
            case .addServer(let server):
                restartQueue.remove(each)
                RPCServer.customRpcs.append(server)
            case .editServer(let original, let edited):
                restartQueue.remove(each)
                replaceCustomRpcServer(original: original, edited: edited)
            case .removeServer(let server):
                restartQueue.remove(each)
                removeServer(server)
            case .enableServer(let server):
                restartQueue.remove(each)
                var servers = serversProvider.enabledServers
                servers.append(server)
                serversProvider.enabledServers = servers
            case .switchDappServer(server: let server):
                restartQueue.remove(each)
                Config.setChainId(server.chainID)
            case .loadUrlInDappBrowser(let url):
                restartQueue.remove(each)
                navigation?.openUrlInDappBrowser(url: url, animated: false)
            case .reloadServers(let servers):
                restartQueue.remove(each)
                serversProvider.enabledServers = servers
            }
        }
    }

    private func replaceCustomRpcServer(original: CustomRPC, edited: CustomRPC) {
        RPCServer.customRpcs = RPCServer.customRpcs.map { $0.chainID == original.chainID ? edited : $0 }
    }

    private func removeServer(_ server: CustomRPC) {
        //Must disable server first because we (might) not have done that if the user had disabled and then remove the server in the UI at the same time. And if we fallback to mainnet when an enabled server's chain ID is not found, this can lead to mainnet appearing twice in the Wallet tab
        let servers = serversProvider.enabledServers.filter { $0.chainID != server.chainID }

        if let i = RPCServer.customRpcs.firstIndex(of: server) {
            RPCServer.customRpcs.remove(at: i)
        }

        serversProvider.enabledServers = servers

        switchBrowserServer(awayFrom: server)
    }

    private func switchBrowserServer(awayFrom server: CustomRPC) {
        guard serversProvider.browserRpcServer.chainID == server.chainID else { return }
        //To be safe, we find a network that is either mainnet/testnet depending on the chain that was removed
        let isTestnet = server.isTestnet
        if let targetServer = serversProvider.enabledServers.first(where: { $0.isTestnet == isTestnet }) {
            Config.setChainId(targetServer.chainID)
        }
    }
}
