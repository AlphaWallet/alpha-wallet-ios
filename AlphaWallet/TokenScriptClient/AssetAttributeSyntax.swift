// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt

enum AssetAttributeSyntax: String {
    //https://tools.ietf.org/html/rfc4517
    //RFC spells it "Boolean", hence not "bool"
    case boolean = "1.3.6.1.4.1.1466.115.121.1.7"
    case directoryString = "1.3.6.1.4.1.1466.115.121.1.15"
    case generalisedTime = "1.3.6.1.4.1.1466.115.121.1.24"
    case iA5String = "1.3.6.1.4.1.1466.115.121.1.26"
    case integer = "1.3.6.1.4.1.1466.115.121.1.27"
    case numericString = "1.3.6.1.4.1.1466.115.121.1.36"

    //Only used internally
    case openSeaTraits = "1"

    var defaultValue: AssetInternalValue {
        switch self {
        case .directoryString, .iA5String:
            return .string("N/A")
        case .generalisedTime:
            return .generalisedTime(.init())
        case .integer:
            return .int(0)
        case .boolean:
            return .bool(false)
        case .numericString:
            return .uint(.init())
        case .openSeaTraits:
            //Should be impossible to reach here
            return .string("N/A")
        }
    }

    func coerceToSyntax(_ value: AssetInternalValue) -> AssetInternalValue? {
        if case .subscribable(let subscribable) = value {
            return coerceSubscribableToSyntax(subscribable)
        } else {
            return coerceNonSubscribableToSyntax(value)
        }
    }

    private func coerceSubscribableToSyntax(_ subscribable: Subscribable<AssetInternalValue>) -> AssetInternalValue? {
        let convertedSubscribable = Subscribable<AssetInternalValue>(nil)
        subscribable.subscribe { value in
            guard let value = value else { return }
            convertedSubscribable.value = self.coerceNonSubscribableToSyntax(value)
        }
        return .subscribable(convertedSubscribable)
    }

    private func coerceNonSubscribableToSyntax(_ value: AssetInternalValue) -> AssetInternalValue? {
        switch self {
        case .directoryString, .iA5String:
            return coerceToString(value)
        case .generalisedTime:
            return coerceToGeneralisedTime(value)
        case .integer:
            return coerceToInteger(value)
        case .boolean:
            return coerceToBoolean(value)
        case .numericString:
            return coerceToNumericString(value)
        case .openSeaTraits:
            return value
        }
    }

    private func coerceToString(_ value: AssetInternalValue) -> AssetInternalValue? {
        switch value {
        case .address(let address):
            return .string(address.eip55String)
        case .string:
            return value
        case .int(let int):
            return .string(String(int))
        case .uint(let bigUInt):
            return .string(String(bigUInt))
        case .bool(let bool):
            return .string(bool ? "true": "false")
        case .generalisedTime, .subscribable, .openSeaNonFungibleTraits:
            return nil
        }
    }

    private func coerceToGeneralisedTime(_ value: AssetInternalValue) -> AssetInternalValue? {
        switch value {
        case .address:
            return nil
        case .string(let string):
            return GeneralisedTime(string: string).flatMap { .generalisedTime($0) }
        case .generalisedTime:
            //TODO but actually impossible for TokenScript's asType to be GeneralizedTime. But maybe it's ok? We might support that in the future?
            return value
        case .int, .uint, .subscribable, .bool, .openSeaNonFungibleTraits:
            return nil
        }
    }

    private func coerceToInteger(_ value: AssetInternalValue) -> AssetInternalValue? {
        switch value {
        case .address:
            return nil
        case .string(let string):
            return BigInt(string).flatMap { .int($0) }
        case .int:
            return value
        case .uint(let bigUInt):
            return .int(BigInt(bigUInt))
        case .bool(let bool):
            if bool {
                return .int(1)
            } else {
                return .int(0)
            }
        case .generalisedTime, .subscribable, .openSeaNonFungibleTraits:
            return nil
        }
    }

    private func coerceToBoolean(_ value: AssetInternalValue) -> AssetInternalValue? {
        switch value {
        case .address:
            return nil
        case .string(let string):
            switch string {
            case "true", "TRUE":
                return .bool(true)
            case "false", "FALSE":
                return .bool(false)
            default:
                return nil
            }
        case .int(let int):
            switch int {
            case BigInt(1):
                return .bool(true)
            case BigInt(0):
                return .bool(false)
            default:
                return nil
            }
        case .uint(let bigUInt):
            return coerceToBoolean(.int(BigInt(bigUInt)))
        case .bool:
            return value
        case .generalisedTime, .subscribable, .openSeaNonFungibleTraits:
            return nil
        }
    }

    private func coerceToNumericString(_ value: AssetInternalValue) -> AssetInternalValue? {
        switch value {
        case .address:
            return nil
        case .string(let string):
            return BigUInt(string).flatMap { .uint($0) }
        case .int(let int):
            return .uint(BigUInt(int))
        case .uint:
            return value
        case .generalisedTime, .bool, .subscribable, .openSeaNonFungibleTraits:
            return nil
        }
    }
}
