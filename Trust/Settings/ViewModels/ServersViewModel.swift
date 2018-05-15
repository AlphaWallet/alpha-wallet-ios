// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import TrustKeystore

struct ServersViewModel {
    let servers: [RPCServer]
    let selectedServer: RPCServer

    var title: String {
        return R.string.localizable.settingsNetworkButtonTitle()
    }

    init(servers: [RPCServer], selectedServer: RPCServer) {
        self.servers = servers
        self.selectedServer = selectedServer
    }

    func server(for indexPath: IndexPath) -> RPCServer  {
        return servers[indexPath.row]
    }

    func isServerSelected(_ server: RPCServer) -> Bool {
        return server.chainID == selectedServer.chainID
    }
}
