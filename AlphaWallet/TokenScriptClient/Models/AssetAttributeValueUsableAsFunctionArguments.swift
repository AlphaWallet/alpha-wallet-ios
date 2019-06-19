// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import TrustKeystore

enum AssetAttributeValueUsableAsFunctionArguments {
    case address(AlphaWallet.Address)
    case string(String)
    case int(BigInt)
    case uint(BigUInt)
    case generalisedTime(GeneralisedTime)
    case bool(Bool)

    init?(assetAttribute: AssetInternalValue) {
        switch assetAttribute {
        case .address(let address):
            self = .address(address)
        case .string(let string):
            self = .string(string)
        case .int(let int):
            self = .int(int)
        case .uint(let uint):
            self = .uint(uint)
        case .generalisedTime(let generalisedTime):
            self = .generalisedTime(generalisedTime)
        case .bool(let bool):
            self = .bool(bool)
        case .openSeaNonFungibleTraits, .subscribable:
            return nil
        }
    }

    //Returns slightly different results based on the functionType (call or transaction) because we use different encoders for them
    func coerce(toArgumentType type: SolidityType, forFunctionType functionType: FunctionOrigin.FunctionType) -> AnyObject? {
        //We could have use a switch on a tuple of 2 values — the input and output types, but that will end up with a switch with a default label; then we'll easily forget to update the switch statement when new matching type conversion pairs become available
        switch type {
        case .address:
            return coerceToAddress(forFunctionType: functionType)
        case .bool:
            return coerceToBool(forFunctionType: functionType)
        case .int, .int8, .int16, .int24, .int32, .int40, .int48, .int56, .int64, .int72, .int80, .int88, .int96, .int104, .int112, .int120, .int128, .int136, .int144, .int152, .int160, .int168, .int176, .int184, .int192, .int200, .int208, .int216, .int224, .int232, .int240, .int248, .int256:
            return coerceToInt(forFunctionType: functionType)
        case .string:
            return coerceToString(forFunctionType: functionType)
        case .uint, .uint8, .uint16, .uint24, .uint32, .uint40, .uint48, .uint56, .uint64, .uint72, .uint80, .uint88, .uint96, .uint104, .uint112, .uint120, .uint128, .uint136, .uint144, .uint152, .uint160, .uint168, .uint176, .uint184, .uint192, .uint200, .uint208, .uint216, .uint224, .uint232, .uint240, .uint248, .uint256:
            return coerceToUInt(forFunctionType: functionType)
        case .void:
            return nil
        }
    }

    private func coerceToAddress(forFunctionType functionType: FunctionOrigin.FunctionType) -> AnyObject? {
        switch self {
        case .address(let address):
            switch functionType {
            case .functionCall:
                return address.eip55String as AnyObject
            case .functionTransaction, .paymentTransaction:
                return Address(address: address) as AnyObject
            }
        case .string(let string):
            switch functionType {
            case .functionCall:
                return AlphaWallet.Address(string: string)?.eip55String as AnyObject
            case .functionTransaction, .paymentTransaction:
                return Address(string: string) as AnyObject
            }
        case .int, .uint, .generalisedTime, .bool:
            return nil
        }
    }

    private func coerceToBool(forFunctionType functionType: FunctionOrigin.FunctionType) -> AnyObject? {
        switch self {
        case .bool(let bool):
            return bool as AnyObject
        case .string(let string):
            switch string {
            case "TRUE", "true":
                return true as AnyObject
            case "FALSE", "false":
                return false as AnyObject
            default:
                return nil
            }
        case .int(let int):
            switch int {
            case 1:
                return true as AnyObject
            case 0:
                return false as AnyObject
            default:
                return nil
            }
        case .uint(let uint):
            switch uint {
            case 1:
                return true as AnyObject
            case 0:
                return false as AnyObject
            default:
                return nil
            }
        case .address, .generalisedTime:
            return nil
        }
    }

    private func coerceToInt(forFunctionType functionType: FunctionOrigin.FunctionType) -> AnyObject? {
        switch self {
        case .int(let int):
            return int as AnyObject
        case .uint(let uint):
            return BigInt(uint) as AnyObject
        case .string(let string):
            return BigInt(string) as AnyObject
        case .address, .generalisedTime, .bool:
            return nil
        }
    }

    private func coerceToString(forFunctionType functionType: FunctionOrigin.FunctionType) -> AnyObject? {
        switch self {
        case .address(let address):
            return address.eip55String as AnyObject
        case .string(let string):
            return string as AnyObject
        case .int(let int):
            return int.description as AnyObject
        case .uint(let uint):
            return uint.description as AnyObject
        case .generalisedTime(let generalisedTime):
            return generalisedTime.formatAsGeneralisedTime as AnyObject
        case .bool(let bool):
            return bool.description as AnyObject
        }
    }

    private func coerceToUInt(forFunctionType functionType: FunctionOrigin.FunctionType) -> AnyObject? {
        switch self {
        case .int(let int):
            return BigUInt(int) as AnyObject
        case .uint(let uint):
            return uint as AnyObject
        case .string(let string):
            return BigUInt(string) as AnyObject
        case .address, .generalisedTime, .bool:
            return nil
        }
    }

    static func dictionary(fromAssetAttributeKeyValues assetAttributeKeyValues: [AttributeId: AssetInternalValue]) -> [AttributeId: AssetAttributeValueUsableAsFunctionArguments] {
        let availableKeyValues: [(AttributeId, AssetAttributeValueUsableAsFunctionArguments)] = assetAttributeKeyValues.map { key, value in
            if let value = AssetAttributeValueUsableAsFunctionArguments(assetAttribute: value) {
                return (key, value)
            } else {
                return nil
            }
        }.compactMap { $0 }
        return Dictionary(uniqueKeysWithValues: availableKeyValues)
    }
}
