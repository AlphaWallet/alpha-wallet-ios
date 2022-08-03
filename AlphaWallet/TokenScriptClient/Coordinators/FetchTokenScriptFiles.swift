// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

class FetchTokenScriptFiles {
    private let assetDefinitionStore: AssetDefinitionStore
    private let tokensDataStore: TokensDataStore
    private let config: Config

    private var contractsInDatabase: [AddressAndOptionalRPCServer] {
        return tokensDataStore.enabledTokens(for: config.enabledServers).filter {
            switch $0.type {
            case .erc20, .erc721, .erc875, .erc721ForTickets, .erc1155:
                return true
            case .nativeCryptocurrency:
                return false
            }
        }.map { AddressAndOptionalRPCServer(address: $0.contractAddress, server: $0.server) }
    }

    private var contractsWithTokenScriptFileFromOfficialRepo: [AlphaWallet.Address] {
        return assetDefinitionStore.contractsWithTokenScriptFileFromOfficialRepo
    }

    init(assetDefinitionStore: AssetDefinitionStore, tokensDataStore: TokensDataStore, config: Config) {
        self.assetDefinitionStore = assetDefinitionStore
        self.tokensDataStore = tokensDataStore
        self.config = config
    }

    private let queue = DispatchQueue(label: "com.FetchAssetDefinitions.UpdateQueue")

    func start() {
        queue.async {
            let contractsAndServers = Array(Set(self.contractsInDatabase + self.contractsWithTokenScriptFileFromOfficialRepo.map { AddressAndOptionalRPCServer(address: $0, server: nil) }))
            self.assetDefinitionStore.fetchXMLs(forContractsAndServers: contractsAndServers)
        }
    }

}
