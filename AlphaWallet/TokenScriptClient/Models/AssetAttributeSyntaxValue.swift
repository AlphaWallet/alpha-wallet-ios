// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt

struct AssetAttributeSyntaxValue {
    private let _value: AssetInternalValue

    let syntax: AssetAttributeSyntax
    var value: AssetInternalValue

    init(syntax: AssetAttributeSyntax, value: AssetInternalValue) {
        self.syntax = syntax
        self._value = value
        self.value = syntax.coerceToSyntax(value) ?? syntax.defaultValue
    }

    init(directoryString: String) {
        self.init(syntax: .directoryString, value: .string(directoryString))
    }

    init(int: BigInt) {
        self.init(syntax: .integer, value: .int(int))
    }

    init(generalisedTime: GeneralisedTime) {
        self.init(syntax: .generalisedTime, value: .generalisedTime(generalisedTime))
    }

    init(openSeaTraits: [OpenSeaNonFungibleTrait]) {
        self.init(syntax: .directoryString, value: .openSeaNonFungibleTraits(openSeaTraits))
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
