// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

struct EnabledServersViewModel {
    let servers: [RPCServer]
    let selectedServers: [RPCServer]

    var title: String {
        return R.string.localizable.settingsEnabledNetworksButtonTitle()
    }

    func server(for indexPath: IndexPath) -> RPCServer {
        return servers[indexPath.row]
    }

    func isServerSelected(_ server: RPCServer) -> Bool {
        return selectedServers.contains(server)
    }
}