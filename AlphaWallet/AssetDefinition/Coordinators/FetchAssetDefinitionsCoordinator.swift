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
            contracts.append(contentsOf: each.enabledObject.filter {
                switch $0.type {
                case .erc20, .erc721, .erc875:
                    return true
                case .nativeCryptocurrency:
                    return false
                }
            }.map { $0.contract })
        }
        assetDefinitionStore.fetchXMLs(forContracts: contracts.compactMap { AlphaWallet.Address(string: $0) })
    }
}