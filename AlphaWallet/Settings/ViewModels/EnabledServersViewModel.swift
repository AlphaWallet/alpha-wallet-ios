// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

struct EnabledServersViewModel {
    enum Mode {
        case testnet
        case mainnet

        var headerText: String {
            switch self {
            case .testnet:
                return R.string.localizable.settingsEnabledNetworksTestnet(preferredLanguages: Languages.preferred()).uppercased()
            case .mainnet:
                return R.string.localizable.settingsEnabledNetworksMainnet(preferredLanguages: Languages.preferred()).uppercased()
            }
        }
    }

    private let mainnets: [RPCServer]
    private let testnets: [RPCServer]

    let servers: [RPCServer]
    let selectedServers: [RPCServer]
    let mode: Mode

    //Cannot infer `mode` from `selectedServers` because of this case: we are in testnet and tap to deselect all of them. Can't know to stay in testnet
    init(servers: [RPCServer], selectedServers: [RPCServer], mode: Mode) {
        self.servers = servers
        self.selectedServers = selectedServers
        self.mainnets = servers.filter { !$0.isTestnet }
        self.testnets = servers.filter { $0.isTestnet }
        self.mode = mode
    }

    var title: String {
        return R.string.localizable.settingsEnabledNetworksButtonTitle(preferredLanguages: Languages.preferred())
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
