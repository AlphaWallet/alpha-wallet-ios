//
//  RestartQueueHandler.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.03.2022.
//

import Foundation

public protocol LoadUrlInDappBrowserProvider: AnyObject {
    func didLoadUrlInDappBrowser(url: URL, in handler: RestartQueueHandler)
}

public final class RestartQueueHandler {
    private let config: Config
    private let restartQueue: RestartTaskQueue

    public convenience init() {
        self.init(config: .init(), restartQueue: .init())
    }

    public init(config: Config, restartQueue: RestartTaskQueue) {
        self.config = config
        self.restartQueue = restartQueue
    }

    public func add(_ task: RestartTaskQueue.Task) {
        restartQueue.add(task)
    }

    public func remove(_ task: RestartTaskQueue.Task) {
        restartQueue.remove(task)
    }

    public func processRestartQueueAfterRestart(provider: LoadUrlInDappBrowserProvider) {
        for each in restartQueue.queue {
            switch each {
            case .addServer, .reloadServers, .editServer, .removeServer, .enableServer, .switchDappServer:
                break
            case .loadUrlInDappBrowser(let url):
                restartQueue.remove(each)
                provider.didLoadUrlInDappBrowser(url: url, in: self)
            }
        }
    }

    public func processRestartQueueBeforeRestart() {
        for each in restartQueue.queue {
            switch each {
            case .addServer(let server):
                restartQueue.remove(each)
                RPCServer.customRpcs.append(server)
            case .editServer(let original, let edited):
                restartQueue.remove(each)
                replaceServer(original: original, edited: edited)
            case .removeServer(let server):
                restartQueue.remove(each)
                removeServer(server)
            case .enableServer(let server):
                restartQueue.remove(each)
                var c = config
                // NOTE: we need to make sure that we don't enableServer test net server when main net is selected.
                // update enabledServers with added server
                var servers = c.enabledServers.filter({ $0.isTestnet == server.isTestnet })
                servers.append(server)
                c.enabledServers = servers
            case .switchDappServer(server: let server):
                restartQueue.remove(each)
                Config.setChainId(server.chainID)
            case .loadUrlInDappBrowser(let url):
                break
            case .reloadServers(let servers):
                restartQueue.remove(each)
                var c = config
                c.enabledServers = servers
            }
        }
    }

    private func replaceServer(original: CustomRPC, edited: CustomRPC) {
        RPCServer.customRpcs = RPCServer.customRpcs.map { $0.chainID == original.chainID ? edited : $0 }
    }

    private func removeServer(_ server: CustomRPC) {
        //Must disable server first because we (might) not have done that if the user had disabled and then remove the server in the UI at the same time. And if we fallback to mainnet when an enabled server's chain ID is not found, this can lead to mainnet appearing twice in the Wallet tab
        let servers = config.enabledServers.filter { $0.chainID != server.chainID }
        var config = self.config
        config.enabledServers = servers
        guard let i = RPCServer.customRpcs.firstIndex(of: server) else { return }
        RPCServer.customRpcs.remove(at: i)
        switchBrowserServer(awayFrom: server, config: config)
    }

    private func switchBrowserServer(awayFrom server: CustomRPC, config: Config) {
        guard Config.getChainId() == server.chainID else { return }
        //To be safe, we find a network that is either mainnet/testnet depending on the chain that was removed
        let isTestnet = server.isTestnet
        if let targetServer = config.enabledServers.first(where: { $0.isTestnet == isTestnet }) {
            Config.setChainId(targetServer.chainID)
        }
    }
}
