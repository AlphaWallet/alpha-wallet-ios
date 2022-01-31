// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt 

struct AssetAttributeSyntaxValue: Hashable {
    static func == (lhs: AssetAttributeSyntaxValue, rhs: AssetAttributeSyntaxValue) -> Bool {
        return lhs.description == rhs.description
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(description)
    }

    private let _value: AssetInternalValue

    let syntax: AssetAttributeSyntax
    var value: AssetInternalValue

    var description: String {
        "\(syntax): \(value.description)"
    }

    init(syntax: AssetAttributeSyntax, value: AssetInternalValue) {
        self.syntax = syntax
        self._value = value
        self.value = syntax.coerceToSyntax(value) ?? syntax.defaultValue
    }

    init(directoryString: String) {
        self.init(syntax: .directoryString, value: .string(directoryString))
    }

    init(bool: Bool) {
        self.init(syntax: .boolean, value: .bool(bool))
    }

    init(int: BigInt) {
        self.init(syntax: .integer, value: .int(int))
    }

    init(generalisedTime: GeneralisedTime) {
        self.init(syntax: .generalisedTime, value: .generalisedTime(generalisedTime))
    }

    init(openSeaTraits: [OpenSeaNonFungibleTrait]) {
        self.syntax = .directoryString
        self._value = .openSeaNonFungibleTraits(openSeaTraits)
        self.value = .openSeaNonFungibleTraits(openSeaTraits)
    }

    init(defaultValueWithSyntax: AssetAttributeSyntax) {
        self.init(syntax: defaultValueWithSyntax, value: defaultValueWithSyntax.defaultValue)
    }

    var stringValue: String? {
        return value.stringValue
    }
    var bytesValue: Data? {
        return value.bytesValue
    }
    var intValue: BigInt? {
        return value.intValue
    }
    var uintValue: BigUInt? {
        return value.uintValue
    }
    var generalisedTimeValue: GeneralisedTime? {
        return value.generalisedTimeValue
    }
    var boolValue: Bool? {
        return value.boolValue
    }
    var subscribableValue: Subscribable<AssetInternalValue>? {
        return value.subscribableValue
    }
    var subscribableStringValue: String? {
        return value.subscribableValue?.value?.stringValue
    }
    var isSubscribableValue: Bool {
        return value.subscribableValue != nil
    }
}

extension Dictionary where Key == AttributeId, Value == AssetAttributeSyntaxValue {
    //This is useful for implementing 3-phase resolution of attributes: resolve the immediate ones (non-function origins), then use those values to resolve the function-origins. There are no user-entry origins at the token level, so we don't need to check for them
    var splitAttributesIntoSubscribablesAndNonSubscribables: (subscribables: [Key: Value], nonSubscribables: [Key: Value]) {
        return (
                subscribables: filter { $0.value.isSubscribableValue },
                nonSubscribables: filter { !$0.value.isSubscribableValue }
        )
    }
}

extension Array where Element == AssetAttributeSyntaxValue {
    var filterToSubscribables: [Subscribable<AssetInternalValue>] {
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
    var tokenIdStringValue: String? {
        self["tokenId"]?.stringValue
    }

    //"setter" functions are intentionally grouped with their complementary "getter" functions
    mutating func setTokenId(string: String) {
        self["tokenId"] = .init(directoryString: string)
    }

    var tokenIdUIntValue: BigUInt? {
        self["tokenId"]?.uintValue
    }

    var nameStringValue: String? {
        self["name"]?.stringValue
    }

    mutating func setName(string: String) {
        self["name"] = .init(directoryString: string)
    }

    var descriptionStringValue: String? {
        self["description"]?.stringValue
    }

    mutating func setDescription(string: String) {
        self["description"] = .init(directoryString: string)
    }

    var imageUrlUrlValue: URL? {
        self["imageUrl"]?.stringValue.flatMap { URL(string: $0) }
    }

    mutating func setImageUrl(string: String) {
        self["imageUrl"] = .init(directoryString: string)
    }

    var thumbnailUrlUrlValue: URL? {
        self["thumbnailUrl"]?.stringValue.flatMap { URL(string: $0) }
    }

    mutating func setThumbnailUrl(string: String) {
        self["thumbnailUrl"] = .init(directoryString: string)
    }

    var externalLinkUrlValue: URL? {
        self["externalLink"]?.stringValue.flatMap { URL(string: $0) }
    }

    mutating func setExternalLink(string: String) {
        self["externalLink"] = .init(directoryString: string)
    }

    var localityStringValue: String? {
        self["locality"]?.stringValue
    }

    var venueStringValue: String? {
        self["venue"]?.stringValue
    }

    var countryAStringValue: String? {
        self["countryA"]?.stringValue
    }

    var countryBStringValue: String? {
        self["countryB"]?.stringValue
    }

    var countryStringValue: String? {
        self["country"]?.stringValue
    }

    var categoryStringValue: String? {
        self["category"]?.stringValue
    }

    var sectionStringValue: String? {
        self["section"]?.stringValue
    }

    var matchIntValue: BigInt? {
        self["match"]?.intValue
    }

    var numeroIntValue: BigInt? {
        self["numero"]?.intValue
    }

    var backgroundColorStringValue: String? {
        get {
            self["backgroundColor"]?.stringValue
        }
        set {
            self["backgroundColor"] = newValue.flatMap { .init(directoryString: $0) }
        }
    }

    var contractImageUrlUrlValue: URL? {
        self["contractImageUrl"]?.stringValue.flatMap { URL(string: $0) }
    }

    var contractImageUrlStringValue: String? {
        self["contractImageUrl"]?.stringValue
    }

    mutating func setContractImageUrl(string: String) {
        self["contractImageUrl"] = .init(directoryString: string)
    }

    var collectionDescriptionStringValue: String? {
        get {
            self["collectionDescription"]?.stringValue
        }
        set {
            self["collectionDescription"] = newValue.flatMap { .init(directoryString: $0) }
        }
    }

    var valueIntValue: BigInt? {
        self["value"]?.intValue
    }

    mutating func setValue(int: BigInt) {
        self["value"] = .init(int: int)
    }

    var timeGeneralisedTimeValue: GeneralisedTime? {
        self["time"]?.generalisedTimeValue
    }

    var collectionCreatedDateGeneralisedTimeValue: GeneralisedTime? {
        self["collectionCreatedDate"]?.generalisedTimeValue
    }

    mutating func setCollectionCreatedDate(generalisedTime: GeneralisedTime) {
        self["collectionCreatedDate"] = .init(generalisedTime: generalisedTime)
    }

    var buildingSubscribableValue: Subscribable<AssetInternalValue>? {
        self["building"]?.subscribableValue
    }

    var streetSubscribableValue: Subscribable<AssetInternalValue>? {
        self["street"]?.subscribableValue
    }

    var stateSubscribableValue: Subscribable<AssetInternalValue>? {
        self["state"]?.subscribableValue
    }

    var localitySubscribableValue: Subscribable<AssetInternalValue>? {
        self["locality"]?.subscribableValue
    }

    var localitySubscribableStringValue: String? {
        self["locality"]?.subscribableStringValue
    }

    var stateSubscribableStringValue: String? {
        self["state"]?.subscribableStringValue
    }

    var streetSubscribableStringValue: String? {
        self["street"]?.subscribableStringValue
    }

    var traitsValue: [OpenSeaNonFungibleTrait]? {
        switch self["traits"]?.value {
        case .openSeaNonFungibleTraits(let traits):
            return traits
        case .address, .string, .int, .uint, .generalisedTime, .bool, .subscribable, .bytes, .none:
            return nil
        }
    }

    var meltStringValue: String? {
        self["meltStringValue"]?.stringValue
    }

    var meltFeeRatio: BigInt? {
        self["meltFeeRatio"]?.intValue
    }

    var meltFeeMaxRatio: BigInt? {
        self["meltFeeMaxRatio"]?.intValue
    }

    var totalSupplyStringValue: String? {
        self["totalSupplyStringValue"]?.stringValue
    }

    var circulatingSupplyStringValue: String? {
        self["circulatingSupplyStringValue"]?.stringValue
    }

    var reserve: String? {
        self["reserve"]?.stringValue
    }

    var nonFungible: Bool? {
        self["nonFungible"]?.boolValue
    }

    var blockHeight: BigInt? {
        self["blockHeight"]?.intValue
    }

    var mintableSupply: BigInt? {
        self["mintableSupply"]?.intValue
    }

    var transferable: String? {
        self["transferable"]?.stringValue
    }

    var supplyModel: String? {
        self["supplyModel"]?.stringValue
    }

    var enjinIssuer: String? {
        let rawValue = self["enjin.issuer"]?.stringValue
        guard let maybeAddress = rawValue.flatMap({ AlphaWallet.Address(string: $0) }) else {
            return rawValue
        }
        return maybeAddress.truncateMiddle
    }

    var created: String? {
        return self["created"]?.stringValue
    }

    var transferFee: String? {
        return self["transferFee"]?.stringValue
    }

    var descriptionAssetInternalValue: AssetInternalValue? {
        self["description"]?.value
    }

    var slug: String? {
        self["slug"]?.stringValue
    }

    var collectionValue: OpenSea.Collection? {
        return self["collection"]?.stringValue.flatMap { rawValue -> OpenSea.Collection? in
            guard let data = rawValue.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(OpenSea.Collection.self, from: data)
        }
    }

    var creatorValue: OpenSea.AssetCreator? {
        return self["creator"]?.stringValue.flatMap { rawValue -> OpenSea.AssetCreator? in
            guard let data = rawValue.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(OpenSea.AssetCreator.self, from: data)
        }
    }

    mutating func setTraits(value: [OpenSeaNonFungibleTrait]) {
        self["traits"] = .init(openSeaTraits: value)
    }

    mutating func setDecimals(int: Int) {
        self["decimals"] = .init(int: BigInt(int))
    }

    mutating func setTokenType(string: String) {
        self["tokenType"] = .init(directoryString: string)
    }

    mutating func setMeltStringValue(string: String?) {
        self["meltStringValue"] = string.flatMap { .init(directoryString: $0) }
    }

    mutating func setMeltFeeRatio(int: Int?) {
        self["meltFeeRatio"] = int.flatMap { .init(int: BigInt($0)) }
    }

    mutating func setMeltFeeMaxRatio(int: Int?) {
        self["meltFeeMaxRatio"] = int.flatMap { .init(int: BigInt($0)) }
    }

    mutating func setTotalSupplyStringValue(string: String?) {
        self["totalSupplyStringValue"] = string.flatMap { .init(directoryString: $0) }
    }

    mutating func setCirculatingSupply(string: String?) {
        self["circulatingSupply"] = string.flatMap { .init(directoryString: $0) }
    }

    mutating func setReserveStringValue(string: String?) {
        self["reserveStringValue"] = string.flatMap { .init(directoryString: $0) }
    }

    mutating func setNonFungible(bool: Bool?) {
        self["nonFungible"] = bool.flatMap { .init(bool: $0) }
    }

    mutating func setBlockHeight(int: Int?) {
        self["blockHeight"] = int.flatMap { .init(int: BigInt($0)) }
    }

    mutating func setMintableSupply(bigInt: BigInt?) {
        self["mintableSupply"] = bigInt.flatMap { .init(int: $0) }
    }

    mutating func setTransferable(string: String?) {
        self["transferable"] = string.flatMap { .init(directoryString: $0) }
    }

    mutating func setSupplyModel(string: String?) {
        self["supplyModel"] = string.flatMap { .init(directoryString: $0) }
    }

    mutating func setIssuer(string: String?) {
        self["enjin.issuer"] = string.flatMap { .init(directoryString: $0) }
    }

    mutating func setCreated(string: String?) {
        self["created"] = string.flatMap { .init(directoryString: $0) }
    }

    mutating func setTransferFee(string: String?) {
        self["transferFee"] = string.flatMap { .init(directoryString: $0) }
    }

    mutating func setCollection(collection: OpenSea.Collection?) {
        self["collection"] = collection.flatMap { collection -> String? in
            let data = try? JSONEncoder().encode(collection)
            return data.flatMap { data in
                String(data: data, encoding: .utf8)
            }
        }.flatMap { .init(directoryString: $0) }
    }

    mutating func setCreator(creator: OpenSea.AssetCreator?) {
        self["creator"] = creator.flatMap { creator -> String? in
            let data = try? JSONEncoder().encode(creator)
            return data.flatMap { data in
                String(data: data, encoding: .utf8)
            }
        }.flatMap { .init(directoryString: $0) }
    }

    mutating func setSlug(string: String?) {
        self["slug"] = string.flatMap { .init(directoryString: $0) }
    }
}
