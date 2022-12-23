// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

enum ServerSelection {
    case server(server: RPCServerOrAuto)
    case multipleServers(servers: [RPCServerOrAuto])

    var asServersOrAnyArray: [RPCServerOrAuto] {
        switch self {
        case .multipleServers:
            return []
        case .server(let server):
            return [server]
        }
    }

    var asServersArray: [RPCServer] {
        switch self {
        case .server(let server):
            return [server.server]
        case .multipleServers(let servers):
            //NOTE: is shouldn't happend, but for case when there several .auto casess
            return Array(Set(servers.map { $0.server }))
        }
    }
}

extension RPCServerOrAuto {
    var server: RPCServer {
        switch self {
        case .server(let value):
            return value
        case .auto:
            return Config().anyEnabledServer()
        }
    }
}

struct ServersViewModel {
    private var initiallySelectedServers: [RPCServerOrAuto]
    private (set) var selectedServers: [RPCServerOrAuto]

    let servers: [RPCServerOrAuto]
    var multipleSessionSelectionEnabled: Bool = false
    var title: String {
        return R.string.localizable.settingsNetworkButtonTitle()
    }

    var descriptionColor: UIColor {
        return Configuration.Color.Semantic.defaultForegroundText
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

    func viewModel(for indexPath: IndexPath) -> ServerImageViewModel {
        let rpcServerOrAuto = server(for: indexPath)
        var viewModel = ServerImageViewModel(server: rpcServerOrAuto, isSelected: isServerSelected(rpcServerOrAuto))
        viewModel.selectionStyle = .none

        return viewModel
    }

    mutating func selectOrDeselectServer(indexPath: IndexPath) {
        let server = server(for: indexPath)

        if multipleSessionSelectionEnabled {
            if isServerSelected(server) {
                guard selectedServers.count > 1 else { return }
                unselectServer(server: server)
            } else {
                selectServer(server: server)
            }
        } else {
            selectedServers.forEach { unselectServer(server: $0) }
            selectServer(server: server)
        }
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
