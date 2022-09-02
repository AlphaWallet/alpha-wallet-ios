// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

struct ServersViewModel {
    private var initiallySelectedServers: [RPCServerOrAuto]
    private (set) var selectedServers: [RPCServerOrAuto]

    let servers: [RPCServerOrAuto]
    var multipleSessionSelectionEnabled: Bool = false
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

    var serversHaveChanged: Bool {
        return Set(selectedServers) != Set(initiallySelectedServers)
    }

    init(servers: [RPCServerOrAuto], selectedServers: [RPCServerOrAuto], displayWarningFooter: Bool? = .none) {
        self.servers = servers
        self.selectedServers = selectedServers
        self.initiallySelectedServers = selectedServers
        self.allowWarningFooter = displayWarningFooter
    }

    func server(for indexPath: IndexPath) -> RPCServerOrAuto {
        return servers[indexPath.row]
    }

    mutating func selectServer(server: RPCServerOrAuto) {
        guard !selectedServers.contains(server) else { return }
        selectedServers.append(server)
    }

    mutating func unselectServer(server: RPCServerOrAuto) {
        guard selectedServers.contains(server) else { return }
        selectedServers.removeAll(where: { $0 == server })
    }

    func isServerSelected(_ server: RPCServerOrAuto) -> Bool {
        return selectedServers.contains(where: { $0 == server })
    }
}
