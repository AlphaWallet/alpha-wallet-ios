// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

struct ServersViewModel {
    private let selectedServer: RPCServerOrAuto

    let servers: [RPCServerOrAuto]

    var title: String {
        return R.string.localizable.settingsNetworkButtonTitle()
    }

    init(servers: [RPCServerOrAuto], selectedServer: RPCServerOrAuto) {
        self.servers = servers
        self.selectedServer = selectedServer
    }

    func server(for indexPath: IndexPath) -> RPCServerOrAuto {
        return servers[indexPath.row]
    }

    func isServerSelected(_ server: RPCServerOrAuto) -> Bool {
        return server == selectedServer
    }
}
