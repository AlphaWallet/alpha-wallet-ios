// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress
import AlphaWalletCore
import AlphaWalletOpenSea
import BigInt

public struct AssetAttributeSyntaxValue: Hashable {
    public static func == (lhs: AssetAttributeSyntaxValue, rhs: AssetAttributeSyntaxValue) -> Bool {
        return lhs.description == rhs.description
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(description)
    }

    private let _value: AssetInternalValue

    public let syntax: AssetAttributeSyntax
    public var value: AssetInternalValue

    public var description: String {
        "\(syntax): \(value.description)"
    }

    public init(syntax: AssetAttributeSyntax, value: AssetInternalValue) {
        self.syntax = syntax
        self._value = value
        self.value = syntax.coerceToSyntax(value) ?? syntax.defaultValue
    }

    public init(directoryString: String) {
        self.init(syntax: .directoryString, value: .string(directoryString))
    }

    public init(bool: Bool) {
        self.init(syntax: .boolean, value: .bool(bool))
    }

    public init(int: BigInt) {
        self.init(syntax: .integer, value: .int(int))
    }

    public init(generalisedTime: GeneralisedTime) {
        self.init(syntax: .generalisedTime, value: .generalisedTime(generalisedTime))
    }

    public init(openSeaTraits: [OpenSeaNonFungibleTrait]) {
        self.syntax = .directoryString
        self._value = .openSeaNonFungibleTraits(openSeaTraits)
        self.value = .openSeaNonFungibleTraits(openSeaTraits)
    }

    public init(defaultValueWithSyntax: AssetAttributeSyntax) {
        self.init(syntax: defaultValueWithSyntax, value: defaultValueWithSyntax.defaultValue)
    }

    public var stringValue: String? {
        return value.stringValue
    }
    public var bytesValue: Data? {
        return value.bytesValue
    }
    public var intValue: BigInt? {
        return value.intValue
    }
    public var uintValue: BigUInt? {
        return value.uintValue
    }
    public var generalisedTimeValue: GeneralisedTime? {
        return value.generalisedTimeValue
    }
    public var boolValue: Bool? {
        return value.boolValue
    }
    public var subscribableValue: Subscribable<AssetInternalValue>? {
        return value.subscribableValue
    }
}

extension Dictionary where Key == AttributeId, Value == AssetAttributeSyntaxValue {
    //This is useful for implementing 3-phase resolution of attributes: resolve the immediate ones (non-function origins), then use those values to resolve the function-origins. There are no user-entry origins at the token level, so we don't need to check for them
    public var splitAttributesIntoSubscribablesAndNonSubscribables: (subscribables: [Key: Value], nonSubscribables: [Key: Value]) {
        return (
            subscribables: filter { $0.value.subscribableValue != nil },
            nonSubscribables: filter { $0.value.subscribableValue == nil }
        )
    }
}

extension Array where Element == AssetAttributeSyntaxValue {
    public var filterToSubscribables: [Subscribable<AssetInternalValue>] {
        return compactMap {
            if case .subscribable(let subscribable) = $0.value {
                return subscribable
            } else {
                return nil
            }
        }
    }
}

extension Dictionary where Key == AttributeId, Value == AssetAttributeSyntaxValue {
    public var tokenIdStringValue: String? {
        self["tokenId"]?.stringValue
    }

    //"setter" functions are intentionally grouped with their complementary "getter" functions
    public mutating func setTokenId(string: String) {
        self["tokenId"] = .init(directoryString: string)
    }

    public var tokenIdUIntValue: BigUInt? {
        self["tokenId"]?.uintValue
    }

    public var nameStringValue: String? {
        self["name"]?.stringValue
    }

    public mutating func setName(string: String) {
        self["name"] = .init(directoryString: string)
    }

    public var descriptionStringValue: String? {
        self["description"]?.stringValue
    }

    public mutating func setDescription(string: String) {
        self["description"] = .init(directoryString: string)
    }

    public var imageUrlUrlValue: URL? {
        self["imageUrl"]?.stringValue.flatMap { WebImageURL(string: $0)?.url }
    }

    public mutating func setImageUrl(string: String) {
        self["imageUrl"] = .init(directoryString: string)
    }

    public var animationUrlUrlValue: URL? {
        self["animationUrl"]?.stringValue.flatMap { WebImageURL(string: $0)?.url }
    }

    public mutating func setAnimationUrl(string: String?) {
        self["animationUrl"] = string.flatMap { .init(directoryString: $0) }
    }

    public var thumbnailUrlUrlValue: URL? {
        self["thumbnailUrl"]?.stringValue.flatMap { WebImageURL(string: $0)?.url }
    }

    public mutating func setThumbnailUrl(string: String) {
        self["thumbnailUrl"] = .init(directoryString: string)
    }

    public var externalLinkUrlValue: URL? {
        self["externalLink"]?.stringValue.flatMap { WebImageURL(string: $0)?.url }
    }

    public mutating func setExternalLink(string: String) {
        self["externalLink"] = .init(directoryString: string)
    }

    public var localityStringValue: String? {
        self["locality"]?.stringValue
    }

    public var venueStringValue: String? {
        self["venue"]?.stringValue
    }

    public var countryAStringValue: String? {
        self["countryA"]?.stringValue
    }

    public var countryBStringValue: String? {
        self["countryB"]?.stringValue
    }

    public var countryStringValue: String? {
        self["country"]?.stringValue
    }

    public var categoryStringValue: String? {
        self["category"]?.stringValue
    }

    public var sectionStringValue: String? {
        self["section"]?.stringValue
    }

    public var matchIntValue: BigInt? {
        self["match"]?.intValue
    }

    public var numeroIntValue: BigInt? {
        self["numero"]?.intValue
    }

    public var backgroundColorStringValue: String? {
        get {
            self["backgroundColor"]?.stringValue
        }
        set {
            self["backgroundColor"] = newValue.flatMap { .init(directoryString: $0) }
        }
    }

    public var contractImageUrlUrlValue: URL? {
        self["contractImageUrl"]?.stringValue.flatMap { URL(string: $0) }
    }

    public var contractImageUrlStringValue: String? {
        self["contractImageUrl"]?.stringValue
    }

    public mutating func setContractImageUrl(string: String) {
        self["contractImageUrl"] = .init(directoryString: string)
    }

    public var collectionDescriptionStringValue: String? {
        get {
            self["collectionDescription"]?.stringValue
        }
        set {
            self["collectionDescription"] = newValue.flatMap { .init(directoryString: $0) }
        }
    }

    public var valueIntValue: BigInt? {
        self["value"]?.intValue
    }

    public mutating func setValue(int: BigInt) {
        self["value"] = .init(int: int)
    }

    public var timeGeneralisedTimeValue: GeneralisedTime? {
        self["time"]?.generalisedTimeValue
    }

    public var collectionCreatedDateGeneralisedTimeValue: GeneralisedTime? {
        self["collectionCreatedDate"]?.generalisedTimeValue
    }

    public mutating func setCollectionCreatedDate(generalisedTime: GeneralisedTime) {
        self["collectionCreatedDate"] = .init(generalisedTime: generalisedTime)
    }

    public var buildingSubscribableValue: Subscribable<AssetInternalValue>? {
        self["building"]?.subscribableValue
    }

    public var streetSubscribableValue: Subscribable<AssetInternalValue>? {
        self["street"]?.subscribableValue
    }

    public var stateSubscribableValue: Subscribable<AssetInternalValue>? {
        self["state"]?.subscribableValue
    }

    public var localitySubscribableValue: Subscribable<AssetInternalValue>? {
        self["locality"]?.subscribableValue
    }

    public var traitsValue: [OpenSeaNonFungibleTrait]? {
        switch self["traits"]?.value {
        case .openSeaNonFungibleTraits(let traits):
            return traits
        case .address, .string, .int, .uint, .generalisedTime, .bool, .subscribable, .bytes, .none:
            return nil
        }
    }

    public var meltStringValue: String? {
        self["meltStringValue"]?.stringValue
    }

    public var meltFeeRatio: BigInt? {
        self["meltFeeRatio"]?.intValue
    }

    public var meltFeeMaxRatio: BigInt? {
        self["meltFeeMaxRatio"]?.intValue
    }

    public var totalSupplyStringValue: String? {
        self["totalSupplyStringValue"]?.stringValue
    }

    public var circulatingSupplyStringValue: String? {
        self["circulatingSupplyStringValue"]?.stringValue
    }

    public var reserve: String? {
        self["reserve"]?.stringValue
    }

    public var nonFungible: Bool? {
        self["nonFungible"]?.boolValue
    }

    public var blockHeight: BigInt? {
        self["blockHeight"]?.intValue
    }

    public var mintableSupply: BigInt? {
        self["mintableSupply"]?.intValue
    }

    public var transferable: String? {
        self["transferable"]?.stringValue
    }

    public var supplyModel: String? {
        self["supplyModel"]?.stringValue
    }

    public var enjinIssuer: String? {
        let rawValue = self["enjin.issuer"]?.stringValue
        guard let maybeAddress = rawValue.flatMap({ AlphaWallet.Address(string: $0) }) else {
            return rawValue
        }
        return maybeAddress.truncateMiddle
    }

    public var created: String? {
        return self["created"]?.stringValue
    }

    public var transferFee: String? {
        return self["transferFee"]?.stringValue
    }

    public var descriptionAssetInternalValue: AssetInternalValue? {
        self["description"]?.value
    }

    public var collectionId: String? {
        self["collectionId"]?.stringValue
    }

    public var collectionValue: AlphaWalletOpenSea.NftCollection? {
        return self["collection"]?.stringValue.flatMap { rawValue -> AlphaWalletOpenSea.NftCollection? in
            guard let data = rawValue.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(AlphaWalletOpenSea.NftCollection.self, from: data)
        }
    }

    public var creatorValue: AssetCreator? {
        return self["creator"]?.stringValue.flatMap { rawValue -> AssetCreator? in
            guard let data = rawValue.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(AssetCreator.self, from: data)
        }
    }

    public mutating func setTraits(value: [OpenSeaNonFungibleTrait]) {
        self["traits"] = .init(openSeaTraits: value)
    }

    public mutating func setTokenType(string: String) {
        self["tokenType"] = .init(directoryString: string)
    }

    public mutating func setMeltStringValue(string: String?) {
        self["meltStringValue"] = string.flatMap { .init(directoryString: $0) }
    }

    public mutating func setMeltFeeRatio(int: Int?) {
        self["meltFeeRatio"] = int.flatMap { .init(int: BigInt($0)) }
    }

    public mutating func setMeltFeeMaxRatio(int: Int?) {
        self["meltFeeMaxRatio"] = int.flatMap { .init(int: BigInt($0)) }
    }

    public mutating func setTotalSupplyStringValue(string: String?) {
        self["totalSupplyStringValue"] = string.flatMap { .init(directoryString: $0) }
    }

    public mutating func setCirculatingSupply(string: String?) {
        self["circulatingSupply"] = string.flatMap { .init(directoryString: $0) }
    }

    public mutating func setReserveStringValue(string: String?) {
        self["reserveStringValue"] = string.flatMap { .init(directoryString: $0) }
    }

    public mutating func setNonFungible(bool: Bool?) {
        self["nonFungible"] = bool.flatMap { .init(bool: $0) }
    }

    public mutating func setBlockHeight(int: Int?) {
        self["blockHeight"] = int.flatMap { .init(int: BigInt($0)) }
    }

    public mutating func setMintableSupply(bigInt: BigInt?) {
        self["mintableSupply"] = bigInt.flatMap { .init(int: $0) }
    }

    public mutating func setTransferable(string: String?) {
        self["transferable"] = string.flatMap { .init(directoryString: $0) }
    }

    public mutating func setSupplyModel(string: String?) {
        self["supplyModel"] = string.flatMap { .init(directoryString: $0) }
    }

    public mutating func setIssuer(string: String?) {
        self["enjin.issuer"] = string.flatMap { .init(directoryString: $0) }
    }

    public mutating func setCreated(string: String?) {
        self["created"] = string.flatMap { .init(directoryString: $0) }
    }

    public mutating func setTransferFee(string: String?) {
        self["transferFee"] = string.flatMap { .init(directoryString: $0) }
    }

    public mutating func setCollection(collection: AlphaWalletOpenSea.NftCollection?) {
        self["collection"] = collection.flatMap { collection -> String? in
            let data = try? JSONEncoder().encode(collection)
            return data.flatMap { data in
                String(data: data, encoding: .utf8)
            }
        }.flatMap { .init(directoryString: $0) }
    }

    public mutating func setCreator(creator: AssetCreator?) {
        self["creator"] = creator.flatMap { creator -> String? in
            let data = try? JSONEncoder().encode(creator)
            return data.flatMap { data in
                String(data: data, encoding: .utf8)
            }
        }.flatMap { .init(directoryString: $0) }
    }

    public mutating func setCollectionId(string: String?) {
        self["collectionId"] = string.flatMap { .init(directoryString: $0) }
    }
}
