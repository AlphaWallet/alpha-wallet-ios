// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

class FetchAssetDefinitionsCoordinator: Coordinator {
    var coordinators: [Coordinator] = []
    private let assetDefinitionStore: AssetDefinitionStore
    private let tokensDataStores: ServerDictionary<TokensDataStore>

    init(assetDefinitionStore: AssetDefinitionStore, tokensDataStores: ServerDictionary<TokensDataStore>) {
        self.assetDefinitionStore = assetDefinitionStore
        self.tokensDataStores = tokensDataStores
    }

    func start() {
        var contracts = [AlphaWallet.Address]()
        for each in tokensDataStores.values {
            contracts.append(contentsOf: each.enabledObject.filter {
                switch $0.type {
                case .erc20, .erc721, .erc875, .erc721ForTickets:
                    return true
                case .nativeCryptocurrency:
                    return false
                }
            }.map { $0.contractAddress })
        }
        assetDefinitionStore.fetchXMLs(forContracts: contracts)
    }
}