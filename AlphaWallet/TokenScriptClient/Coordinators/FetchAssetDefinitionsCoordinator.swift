// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

class FetchAssetDefinitionsCoordinator: Coordinator {
    var coordinators: [Coordinator] = []
    private let assetDefinitionStore: AssetDefinitionStore
    private let tokensDataStore: TokensDataStore
    private let config: Config

    private var contractsInDatabase: [AlphaWallet.Address] {
        var contracts = [AlphaWallet.Address]()
        contracts.append(contentsOf: tokensDataStore.enabledTokens(for: config.enabledServers).filter {
            switch $0.type {
            case .erc20, .erc721, .erc875, .erc721ForTickets, .erc1155:
                return true
            case .nativeCryptocurrency:
                return false
            }
        }.map { $0.contractAddress })
        
        return contracts
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
            let contracts = Array(Set(self.contractsInDatabase + self.contractsWithTokenScriptFileFromOfficialRepo))
            self.assetDefinitionStore.fetchXMLs(forContracts: contracts)
        }
    }

}
