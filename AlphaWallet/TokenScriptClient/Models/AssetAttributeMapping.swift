// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Kanna

struct AssetAttributeMapping {
    private let mapping: XMLElement
    private let xmlContext: XmlContext

    init(mapping: XMLElement, xmlContext: XmlContext) {
        self.mapping = mapping
        self.xmlContext = xmlContext
    }

    func map(fromKey key: AssetInternalValue) -> AssetInternalValue? {
        if case .subscribable(let subscribableKey) = key {
            return map(fromSubscribableKey: subscribableKey)
        } else {
            return map(fromNonSubscribableKey: key)
        }
    }

    private func map(fromSubscribableKey subscribableKey: Subscribable<AssetInternalValue>) -> AssetInternalValue {
        let mappedSubscribable = Subscribable<AssetInternalValue>(nil)
        subscribableKey.subscribe { value in
            guard let value = value else { return }
            guard let keyString = self.convertKeyToString(value) else { return }
            mappedSubscribable.value = XMLHandler.getMappingOptionValue(fromMappingElement: self.mapping, xmlContext: self.xmlContext, withKey: keyString).flatMap { .string($0) }
        }
        return .subscribable(mappedSubscribable)
    }

    private func map(fromNonSubscribableKey key: AssetInternalValue) -> AssetInternalValue? {
        guard let keyString = convertKeyToString(key) else { return nil }
        return XMLHandler.getMappingOptionValue(fromMappingElement: mapping, xmlContext: xmlContext, withKey: keyString).flatMap { .string($0) }
    }

    //Not every case is possible because mapping's input come from origins like ethereum function calls. They are specified with as="int", etc. But we handle them if we can so they will work in the future when we support additional types
    private func convertKeyToString(_ key: AssetInternalValue) -> String? {
        switch key {
        case .address(let address):
            return address.eip55String
        case .string(let string), .bytes(let string):
            return string
        case .int(let int):
            return String(int)
        case .uint(let bigUInt):
            return String(bigUInt)
        case .generalisedTime(let generalisedTime):
            return generalisedTime.formatAsGeneralisedTime
        case .bool(let bool):
            return bool ? "true" : "false"
        case .openSeaNonFungibleTraits, .subscribable:
            return nil
        }
    }
}
