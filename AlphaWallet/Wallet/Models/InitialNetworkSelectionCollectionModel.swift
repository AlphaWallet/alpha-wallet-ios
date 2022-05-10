//
//  InitialNetworkSelectionCollectionModel.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 10/5/22.
//

import UIKit

struct InitialNetworkSelectionCollectionModel {

    // MARK: - variables (private)

    private let servers: [RPCServer] // = RPCServer.allCases

    // MARK: - accessors

    private(set) var filtered: [RPCServer] // = servers
    private(set) var selected: Set<RPCServer> // = Set<RPCServer>()
    var count: Int {
        filtered.count
    }

    // MARK: - Initializers
    init() {
        servers = RPCServer.allCases.filter { !$0.isTestnet }
        filtered = servers
        selected = []
    }

    // MARK: - functions

    mutating func filter(keyword rawKeyword: String) {
        let keyword = rawKeyword.lowercased().trimmed
        if keyword.isEmpty {
            filtered = servers
            return
        }
        filtered = servers.filter({
            $0.name.lowercased().contains(keyword) || String($0.chainID).contains(keyword)
        })
    }

    mutating func addSelected(server: RPCServer) {
        selected.insert(server)
    }

    mutating func removeSelected(server: RPCServer) {
        selected.remove(server)
    }

    func isSelected(server: RPCServer) -> Bool {
        selected.contains(server)
    }

    func server(for indexPath: IndexPath) -> RPCServer {
        let row = indexPath.row
        return filtered[row]
    }
    
}
