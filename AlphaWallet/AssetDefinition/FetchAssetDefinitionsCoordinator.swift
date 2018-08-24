// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

class FetchAssetDefinitionsCoordinator: Coordinator {
    var coordinators: [Coordinator] = []
    private let assetDefinitionStore: AssetDefinitionStore
    private let tokensDataStore: TokensDataStore

    init(assetDefinitionStore: AssetDefinitionStore, tokensDataStore: TokensDataStore) {
        self.assetDefinitionStore = assetDefinitionStore
        self.tokensDataStore = tokensDataStore
    }

    func start() {
        let contracts = tokensDataStore.enabledObject.filter { $0.type == .erc875 || $0.type == .erc721 }.map { $0.contract }
        assetDefinitionStore.fetchXMLs(forContracts: contracts)
    }
}
