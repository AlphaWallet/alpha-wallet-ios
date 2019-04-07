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
        var contracts = [String]()
        for each in tokensDataStores.values {
            contracts.append(contentsOf: each.enabledObject.filter { $0.type == .erc875 || $0.type == .erc721 }.map { $0.contract })
        }
        assetDefinitionStore.fetchXMLs(forContracts: contracts)
    }
}