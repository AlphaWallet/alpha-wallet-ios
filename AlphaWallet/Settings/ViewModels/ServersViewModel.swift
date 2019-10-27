// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct ServersViewModel {
    private let selectedServer: RPCServerOrAuto

    let servers: [RPCServerOrAuto]

    var title: String {
        return R.string.localizable.settingsNetworkButtonTitle()
    }

    var descriptionColor: UIColor {
        return GroupedTable.Color.title
    }

    var descriptionText: String {
        return R.string.localizable.browserSettingsNetworkDescriptionTitle()
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
