// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletFoundation

struct EnabledServersViewModel {
    private let mainnets: [RPCServer]
    private let testnets: [RPCServer]
    private let config: Config
    private let restartQueue: RestartTaskQueue
    private var serversSelectedInPreviousMode: [RPCServer]?

    var sectionIndices: IndexSet {
        IndexSet(integersIn: Range(uncheckedBounds: (lower: 0, sections.count)))
    }
    let sections: [Section] = [.mainnet, .testnet]
    let servers: [RPCServer]
    private (set) var selectedServers: [RPCServer]
    private (set) var mode: Mode

    //Cannot infer `mode` from `selectedServers` because of this case: we are in testnet and tap to deselect all of them. Can't know to stay in testnet
    init(servers: [RPCServer], selectedServers: [RPCServer], mode: Mode, restartQueue: RestartTaskQueue, config: Config) {
        self.servers = servers
        self.selectedServers = selectedServers
        self.mainnets = servers.filter { !$0.isTestnet }
        self.testnets = servers.filter { $0.isTestnet }
        self.mode = mode
        self.restartQueue = restartQueue
        self.config = config
    }

    var title: String {
        return R.string.localizable.settingsEnabledNetworksButtonTitle("(\(selectedServers.count))")
    }

    func serverViewModel(indexPath: IndexPath) -> ServerImageViewModel {
        let server = server(for: indexPath)
        let warningImage = server.isDeprecated ? R.image.gasWarning() : nil
        
        return ServerImageViewModel(server: .server(server), isSelected: isServerSelected(server), isAvailableToSelect: !server.isDeprecated, warningImage: warningImage)
    }

    mutating func switchMode(to mode: Mode) {
        self.mode = mode
        if let serversSelectedInPreviousMode = serversSelectedInPreviousMode {
            self.serversSelectedInPreviousMode = selectedServers
            self.selectedServers = serversSelectedInPreviousMode
        } else {
            serversSelectedInPreviousMode = selectedServers
            selectedServers = mode == .mainnet ? Constants.defaultEnabledServers : Constants.defaultEnabledTestnetServers
        }
    }

    mutating func selectServer(indexPath: IndexPath) {
        let server = server(for: indexPath)
        let servers: [RPCServer]
        if selectedServers.contains(server) {
            servers = selectedServers - [server]
        } else {
            servers = selectedServers + [server]
        }
        self.selectedServers = servers
    }

    @discardableResult func pushReloadServersIfNeeded() -> Bool {
        let servers = selectedServers
        //Defensive. Shouldn't allow no server to be selected
        guard !servers.isEmpty else { return false }

        let isUnchanged = Set(config.enabledServers) == Set(servers)
        if isUnchanged {
            //no-op
        } else {
            restartQueue.add(.reloadServers(servers))
        }
        return !isUnchanged
    }

    func markForDeletion(server: RPCServer) -> Bool {
        guard let customRpc = server.customRpc else { return false }
        pushReloadServersIfNeeded()
        restartQueue.add(.removeServer(customRpc))

        return true
    }

    func numberOfRowsInSection(_ section: Int) -> Int {
        switch sections[section] {
        case .testnet:
            return serverCount(forMode: .testnet)
        case .mainnet:
            return serverCount(forMode: .mainnet)
        }
    }

    func server(for indexPath: IndexPath) -> RPCServer {
        switch mode {
        case .testnet:
            return testnets[indexPath.row]
        case .mainnet:
            return mainnets[indexPath.row]
        }
    }

    func isServerSelected(_ server: RPCServer) -> Bool {
        selectedServers.contains(server)
    }

    func serverCount(forMode mode: Mode) -> Int {
        guard mode == self.mode else { return 0 }
        switch mode {
        case .testnet:
            return testnets.count
        case .mainnet:
            return mainnets.count
        }
    }
}

extension EnabledServersViewModel {
    enum Section {
        case testnet
        case mainnet
    }

    enum Mode {
        case testnet
        case mainnet

        var headerText: String {
            switch self {
            case .testnet:
                return R.string.localizable.settingsEnabledNetworksTestnet().uppercased()
            case .mainnet:
                return R.string.localizable.settingsEnabledNetworksMainnet().uppercased()
            }
        }
    }
}
