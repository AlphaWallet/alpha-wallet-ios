// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

protocol AssetDefinitionBackingStore {
    var delegate: AssetDefinitionBackingStoreDelegate? { get set }

    subscript(contract: String) -> String? { get set }
    func lastModifiedDataOfCachedAssetDefinitionFile(forContract contract: String) -> Date?
    func forEachContractWithXML(_ body: (String) -> Void)
    func isOfficial(contract: String) -> Bool
}

extension AssetDefinitionBackingStore {
    func standardizedName(ofContract contract: String) -> String {
        return contract.add0x.lowercased()
    }
}

protocol AssetDefinitionBackingStoreDelegate {
    func invalidateAssetDefinition(forContract contract: String)
}
