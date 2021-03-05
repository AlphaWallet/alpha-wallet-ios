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

    var displayWarningFooter: Bool {
        if let value = allowWarningFooter {
            return value
        } else {
            return servers.count != EnabledServersCoordinator.serversOrdered.count
        }
    }

    var descriptionText: String {
        return R.string.localizable.browserSettingsNetworkDescriptionTitle()
    }
    private var allowWarningFooter: Bool?

    init(servers: [RPCServerOrAuto], selectedServer: RPCServerOrAuto, displayWarningFooter: Bool? = .none) {
        self.servers = servers
        self.selectedServer = selectedServer
        self.allowWarningFooter = displayWarningFooter
    }

    func server(for indexPath: IndexPath) -> RPCServerOrAuto {
        return servers[indexPath.row]
    }

    func isServerSelected(_ server: RPCServerOrAuto) -> Bool {
        return server == selectedServer
    }
}
