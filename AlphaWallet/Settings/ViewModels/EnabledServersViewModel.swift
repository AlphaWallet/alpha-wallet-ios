// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

struct EnabledServersViewModel {
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

    private let mainnets: [RPCServer]
    private let testnets: [RPCServer]

    let servers: [RPCServer]
    let selectedServers: [RPCServer]
    let mode: Mode

    init(servers: [RPCServer], selectedServers: [RPCServer]) {
        self.servers = servers
        self.selectedServers = selectedServers
        self.mainnets = servers.filter { !$0.isTestnet }
        self.testnets = servers.filter { $0.isTestnet }
        if selectedServers.contains(where: { $0.isTestnet }) {
            self.mode = .testnet
        } else {
            self.mode = .mainnet
        }
    }

    var title: String {
        return R.string.localizable.settingsEnabledNetworksButtonTitle()
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