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
    var testnetEnabled: Bool

    //Cannot infer `mode` from `selectedServers` because of this case: we are in testnet and tap to deselect all of them. Can't know to stay in testnet
    init(servers: [RPCServer], selectedServers: [RPCServer], restartQueue: RestartTaskQueue, config: Config) {
        self.servers = servers
        self.selectedServers = selectedServers
        self.mainnets = servers.filter { !$0.isTestnet }
        self.testnets = servers.filter { $0.isTestnet }
        self.restartQueue = restartQueue
        self.config = config

        testnetEnabled = selectedServers.contains(where: { $0.isTestnet })
    }

    var title: String {
        return R.string.localizable.settingsEnabledNetworksButtonTitle("(\(selectedServers.count))")
    }

    func serverViewModel(indexPath: IndexPath) -> ServerImageViewModel {
        let server = server(for: indexPath)
        
        return ServerImageViewModel(
            server: .server(server),
            isSelected: isServerSelected(server),
            isAvailableToSelect: !server.isDeprecated,
            warningImage: server.isDeprecated ? R.image.gasWarning() : nil)
    }

    mutating func enableTestnet(_ enabled: Bool) {
        testnetEnabled = enabled

        if let serversSelectedInPreviousMode = serversSelectedInPreviousMode {
            self.serversSelectedInPreviousMode = selectedServers
            self.selectedServers = serversSelectedInPreviousMode
        } else {
            serversSelectedInPreviousMode = selectedServers

            if testnetEnabled {
                selectedServers = Array(Set(selectedServers + Constants.defaultEnabledTestnetServers))
            } else {
                selectedServers = selectedServers.filter { !$0.isTestnet }
            }
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
            return testnetEnabled ? testnets.count : 0
        case .mainnet:
            return mainnets.count
        }
    }

    func server(for indexPath: IndexPath) -> RPCServer {
        switch sections[indexPath.section] {
        case .testnet:
            return testnets[indexPath.row]
        case .mainnet:
            return mainnets[indexPath.row]
        }
    }

    func isServerSelected(_ server: RPCServer) -> Bool {
        selectedServers.contains(server)
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
