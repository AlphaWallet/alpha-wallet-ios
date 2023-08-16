//
//  InitialNetworkSelectionCollectionModel.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 10/5/22.
//

import UIKit
import AlphaWalletFoundation

struct InitialNetworkSelectionCollectionModel {

    static let defaultMainnetServers: Set<RPCServer> = [.main, .xDai, .polygon]
    static let defaultTestnetServers: Set<RPCServer> = [.goerli, .sepolia]

    // MARK: - enums

    enum Mode: Int, CaseIterable {
        case mainnet = 0
        case testnet = 1
    }

    // MARK: - variables (private)

    private let mainnetServers: [RPCServer]
    private let testnetServers: [RPCServer]
    private var filteredMainnetServers: [RPCServer]
    private var filteredTestnetServers: [RPCServer]
    private var selectedMainnetServers: Set<RPCServer>
    private var selectedTestnetServers: Set<RPCServer>

    // MARK: - variables

    private(set) var mode: InitialNetworkSelectionCollectionModel.Mode = .mainnet

    // MARK: - accessors

    var count: Int {
        switch mode {
        case .mainnet:
            return filteredMainnetServers.count
        case .testnet:
            return filteredTestnetServers.count
        }
    }

    var filtered: [RPCServer] {
        switch mode {
        case .mainnet:
            return filteredMainnetServers
        case .testnet:
            return filteredTestnetServers
        }
    }

    private(set) var selected: Set<RPCServer> {
        get {
            switch mode {
            case .mainnet:
                return selectedMainnetServers
            case .testnet:
                return selectedTestnetServers
            }
        }
        set (newValue) {
            switch mode {
            case .mainnet:
                selectedMainnetServers = newValue
            case .testnet:
                selectedTestnetServers = newValue
            }
        }
    }

    // MARK: - Initializers

    init(servers: [RPCServer] = RPCServer.allCases) {
        mainnetServers = servers.filter { !$0.isTestnet }
        testnetServers = servers.filter { $0.isTestnet }
        filteredMainnetServers = mainnetServers
        filteredTestnetServers = testnetServers
        selectedMainnetServers = InitialNetworkSelectionCollectionModel.defaultMainnetServers
        selectedTestnetServers = InitialNetworkSelectionCollectionModel.defaultTestnetServers
    }

    // MARK: - functions (public)

    mutating func filter(keyword rawKeyword: String) {
        let keyword = rawKeyword.lowercased().trimmed
        if keyword.isEmpty {
            filteredMainnetServers = mainnetServers
            filteredTestnetServers = testnetServers
            return
        }
        filteredMainnetServers = mainnetServers.filter { $0.match(keyword: keyword) }
        filteredTestnetServers = testnetServers.filter { $0.match(keyword: keyword) }
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

    func countFor(mode: InitialNetworkSelectionCollectionModel.Mode) -> Int {
        switch mode {
        case .mainnet:
            return filteredMainnetServers.count
        case .testnet:
            return filteredTestnetServers.count
        }
    }

    mutating func set(mode: InitialNetworkSelectionCollectionModel.Mode) {
        self.mode = mode
        if selected.isEmpty {
            switch mode {
            case .mainnet:
                selectedMainnetServers = InitialNetworkSelectionCollectionModel.defaultMainnetServers
            case .testnet:
                selectedTestnetServers = InitialNetworkSelectionCollectionModel.defaultTestnetServers
            }
        }
    }

}

fileprivate extension RPCServer {
    func match(keyword: String) -> Bool {
        self.name.lowercased().contains(keyword) || String(self.chainID).contains(keyword)
    }
}
