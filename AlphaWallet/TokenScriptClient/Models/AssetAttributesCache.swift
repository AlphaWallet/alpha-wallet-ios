// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt

private typealias ContractTokenIdsAttributeValues = [TokenId: [AttributeId: CachedAssetAttribute]]

class AssetAttributesCache {
    private var resolvedAttributesData: AssetAttributesCacheData
    private var functionOriginAttributes: ThreadSafeDictionary<AlphaWallet.Address, [AttributeId: AssetAttribute]> = .init()
    private var functionOriginSubscribables: ThreadSafeDictionary<AlphaWallet.Address, [TokenId: [AttributeId: Subscribable<AssetInternalValue>]]> = .init()

    weak var assetDefinitionStore: AssetDefinitionStore?

    init(assetDefinitionStore: AssetDefinitionStore) {
        self.assetDefinitionStore = assetDefinitionStore
        let decoder = JSONDecoder()
        //TODO read from JSON file/database (if it exists)
        self.resolvedAttributesData = (try? decoder.decode(AssetAttributesCacheData.self, from: Data())) ?? .init()
        setUpClearCacheWhenTokenScriptChanges()
    }

    private func setUpClearCacheWhenTokenScriptChanges() {
        assetDefinitionStore?.subscribeToBodyChanges { [weak self] contract in
            guard let strongSelf = self else { return }
            strongSelf.resolvedAttributesData.remove(contract: contract)
            strongSelf.functionOriginAttributes.removeValue(forKey: contract)
            strongSelf.functionOriginSubscribables.removeValue(forKey: contract)
        }
    }

    func cache(attribute: AssetAttribute, attributeId: AttributeId, value: AssetInternalValue, forContract contract: AlphaWallet.Address, tokenId: TokenId) {
        var contractData: ContractTokenIdsAttributeValues = resolvedAttributesData[contract] ?? .init()
        defer { resolvedAttributesData[contract] = contractData }
        let cachedAttribute = CachedAssetAttribute(type: .token, id: attributeId, value: value)
        var tokenIdData = contractData[tokenId] ?? .init()
        defer { contractData[tokenId] = tokenIdData }
        tokenIdData[attributeId] = cachedAttribute
    }

    func cache(attributes: [AttributeId: AssetAttribute], values: [AttributeId: AssetInternalValue], forContract contract: AlphaWallet.Address, tokenId: TokenId) {
        if functionOriginAttributes[contract] == nil {
            functionOriginAttributes[contract] = attributes
        }

        var contractSubscribables = functionOriginSubscribables[contract] ?? .init()
        defer { functionOriginSubscribables[contract] = contractSubscribables }
        var tokenIdSubscribables = contractSubscribables[tokenId] ?? .init()
        defer { contractSubscribables[tokenId] = tokenIdSubscribables }
        for (attributeId, attribute) in attributes {
            guard attribute.isFunctionOriginBased, let value = values[attributeId] else { continue }
            switch value {
            case .subscribable(let subscribable):
                tokenIdSubscribables[attributeId] = subscribable
                subscribable.subscribe { [weak self] value in
                    guard let strongSelf = self else { return }
                    guard let value = value else { return }
                    //We really expect the data to be available if the subscribable fires later. And not available if subscribable has already been resolved
                    guard var tokenData: [AttributeId: CachedAssetAttribute] = strongSelf.resolvedAttributesData[contract]?[tokenId] else { return }
                    defer {
                        if var contractData = strongSelf.resolvedAttributesData[contract] {
                            contractData[tokenId] = tokenData
                            strongSelf.resolvedAttributesData[contract] = contractData
                            //TODO good chance to write to disk? Maybe limit writing to every sec or 300msec?
                        }
                    }
                    tokenData[attributeId] = CachedAssetAttribute(type: .token, id: attributeId, value: value)
                }
            case .address, .string, .int, .uint, .generalisedTime, .bool, .bytes:
                break
            case .openSeaNonFungibleTraits:
                break
            }
        }

        var contractData: ContractTokenIdsAttributeValues = resolvedAttributesData[contract] ?? .init()
        defer { resolvedAttributesData[contract] = contractData }
        let tokenValues: [(AttributeId, CachedAssetAttribute)] = values.compactMap { each in
            let attributeId = each.key
            let value = each.value
            //TODO this doesn't support action-level
            return value.resolvedValue.flatMap { (attributeId, .init(type: .token, id: attributeId, value: $0)) }
        }
        contractData[tokenId] = Dictionary(tokenValues) { _, new in new }
    }

    func getValues(forContract contractAddress: AlphaWallet.Address, tokenId: TokenId) -> [AttributeId: AssetInternalValue]? {
        //Explicitly typed so AppCode knows
        guard let values: [AttributeId: CachedAssetAttribute] = resolvedAttributesData[contractAddress]?[tokenId] else { return nil }
        let results = values.mapValues { $0.value }
        let subscribablesOptional: [(AttributeId, AssetInternalValue)]? = functionOriginSubscribables[contractAddress]?[tokenId]?.map { each in
            let attributeId = each.key
            let subscribable = each.value
            return (attributeId, .subscribable(subscribable))
        }
        if let subscribables = subscribablesOptional {
            return results.merging(subscribables) { _, new in new }
        } else {
            return results
        }
    }
}

struct AssetAttributesCacheData: Codable {
    private var contracts = [AlphaWallet.Address: ContractTokenIdsAttributeValues]()

    fileprivate subscript(contract: AlphaWallet.Address) -> ContractTokenIdsAttributeValues? {
        get {
            return contracts[contract]
        }
        set {
            contracts[contract] = newValue
        }
    }

    mutating func remove(contract: AlphaWallet.Address) {
        contracts.removeValue(forKey: contract)
    }
}

enum CachedAssetAttributeType: Int, Codable {
    case token
    case action
}

struct CachedAssetAttribute: Codable {
    let type: CachedAssetAttributeType
    let id: AttributeId
    let value: AssetInternalValue
}
