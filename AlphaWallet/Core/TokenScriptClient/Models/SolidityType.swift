// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import BigInt

enum SolidityType: String {
    case address
    case bool
    case bytes
    case bytes1, bytes2, bytes3, bytes4, bytes5, bytes6, bytes7, bytes8, bytes9, bytes10, bytes11, bytes12, bytes13, bytes14, bytes15, bytes16, bytes17, bytes18, bytes19, bytes20, bytes21, bytes22, bytes23, bytes24, bytes25, bytes26, bytes27, bytes28, bytes29, bytes30, bytes31, bytes32
    case int, int8, int16, int24, int32, int40, int48, int56, int64, int72, int80, int88, int96, int104, int112, int120, int128, int136, int144, int152, int160, int168, int176, int184, int192, int200, int208, int216, int224, int232, int240, int248, int256
    case string
    case uint, uint8, uint16, uint24, uint32, uint40, uint48, uint56, uint64, uint72, uint80, uint88, uint96, uint104, uint112, uint120, uint128, uint136, uint144, uint152, uint160, uint168, uint176, uint184, uint192, uint200, uint208, uint216, uint224, uint232, uint240, uint248, uint256
    case void

    func coerce(value originalValue: AssetInternalValue) -> AssetInternalValue? {
        switch self {
        case .address:
            return coerceAsAddress(originalValue)
        case .uint, .uint8, .uint16, .uint24, .uint32, .uint40, .uint48, .uint56, .uint64, .uint72, .uint80, .uint88, .uint96, .uint104, .uint112, .uint120, .uint128, .uint136, .uint144, .uint152, .uint160, .uint168, .uint176, .uint184, .uint192, .uint200, .uint208, .uint216, .uint224, .uint232, .uint240, .uint248, .uint256:
            return coerceAsUInt(originalValue)
        case .bool:
            return coerceAsBool(originalValue)
        case .bytes:
            //TODO check if bytes and bytesX are treated the same way
            return nil
        case .bytes1, .bytes2, .bytes3, .bytes4, .bytes5, .bytes6, .bytes7, .bytes8, .bytes9, .bytes10, .bytes11, .bytes12, .bytes13, .bytes14, .bytes15, .bytes16, .bytes17, .bytes18, .bytes19, .bytes20, .bytes21, .bytes22, .bytes23, .bytes24, .bytes25, .bytes26, .bytes27, .bytes28, .bytes29, .bytes30, .bytes31, .bytes32:
            //TODO check if bytes and bytesX are treated the same way
            return nil
        case .string:
            return coerceAsString(originalValue)
        case .int, .int8, .int16, .int24, .int32, .int40, .int48, .int56, .int64, .int72, .int80, .int88, .int96, .int104, .int112, .int120, .int128, .int136, .int144, .int152, .int160, .int168, .int176, .int184, .int192, .int200, .int208, .int216, .int224, .int232, .int240, .int248, .int256:
            return coerceAsInt(originalValue)
        case .void:
            return nil
        }
    }

    private func coerceAsAddress(_ originalValue: AssetInternalValue) -> AssetInternalValue? {
        switch originalValue {
        case .address:
            return originalValue
        case .string(let value):
            return AlphaWallet.Address(string: value).flatMap { .address($0) }
        case .int:
            return nil
        case .uint:
            return nil
        case .generalisedTime:
            return nil
        case .bool:
            return nil
        case .subscribable(let subscribable):
            if let resolvedValue = subscribable.value {
                return coerce(value: resolvedValue)
            } else {
                return nil
            }
        case .bytes:
            return nil
        case .openSeaNonFungibleTraits:
            return nil
        }
    }

    private func coerceAsBool(_ originalValue: AssetInternalValue) -> AssetInternalValue? {
        switch originalValue {
        case .address:
            return nil
        case .string(let value):
            if value == "true" || value == "TRUE" {
                return .bool(true)
            } else if value == "false" || value == "FALSE" {
                return .bool(false)
            } else {
                return nil
            }
        case .int:
            return nil
        case .uint:
            return nil
        case .generalisedTime:
            return nil
        case .bool:
            return originalValue
        case .subscribable(let subscribable):
            if let resolvedValue = subscribable.value {
                return coerce(value: resolvedValue)
            } else {
                return nil
            }
        case .bytes:
            return nil
        case .openSeaNonFungibleTraits:
            return nil
        }
    }

    private func coerceAsString(_ originalValue: AssetInternalValue) -> AssetInternalValue? {
        switch originalValue {
        case .address(let value):
            return .string(value.eip55String)
        case .string:
            return originalValue
        case .int(let value):
            return .string(String(value))
        case .uint(let value):
            return .string(String(value))
        case .generalisedTime(let value):
            return .string(value.formatAsGeneralisedTime)
        case .bool(let value):
            return .string(String(value))
        case .subscribable(let subscribable):
            if let resolvedValue = subscribable.value {
                return coerce(value: resolvedValue)
            } else {
                return nil
            }
        case .bytes:
            return nil
        case .openSeaNonFungibleTraits:
            return nil
        }
    }

    private func coerceAsUInt(_ originalValue: AssetInternalValue) -> AssetInternalValue? {
        switch originalValue {
        case .address:
            return nil
        case .string(let value):
            if value.isValidBigUInt {
                return BigUInt(value).flatMap { .uint($0) }
            } else {
                return nil
            }
        case .int(let value):
            if value > 0 {
                return .uint(BigUInt(value))
            } else {
                return nil
            }
        case .uint:
            return originalValue
        case .generalisedTime:
            return nil
        case .bool:
            return nil
        case .subscribable(let subscribable):
            if let resolvedValue = subscribable.value {
                return coerce(value: resolvedValue)
            } else {
                return nil
            }
        case .bytes:
            return nil
        case .openSeaNonFungibleTraits:
            return nil
        }
    }

    private func coerceAsInt(_ originalValue: AssetInternalValue) -> AssetInternalValue? {
        switch originalValue {
        case .address:
            return nil
        case .string(let value):
            if value.isValidBigInt {
                return BigInt(value).flatMap { .int($0) }
            } else {
                return nil
            }
        case .int:
            return originalValue
        case .uint(let value):
            return .int(BigInt(value))
        case .generalisedTime:
            return nil
        case .bool:
            return nil
        case .subscribable(let subscribable):
            if let resolvedValue = subscribable.value {
                return coerce(value: resolvedValue)
            } else {
                return nil
            }
        case .bytes:
            return nil
        case .openSeaNonFungibleTraits:
            return nil
        }
    }
}

fileprivate extension String {
    private static let regexToCheckIsValidBigUInt = (try? NSRegularExpression(pattern: "^\\d+$", options: .init()))!
    private static let regexToCheckIsValidBigInt = (try? NSRegularExpression(pattern: "^-?\\d+$", options: .init()))!

    //This is needed because BigUInt(_:radix:) crashes if the input is not a valid BigUInt. e.g. `BigUInt("xxx")`
    var isValidBigUInt: Bool {
        let range = NSRange(location: 0, length: utf16.count)
        return String.regexToCheckIsValidBigUInt.firstMatch(in: self, options: [], range: range) != nil
    }

    //This is needed because BigInt(_:radix:) crashes if the input is not a valid BigInt. e.g. `BigInt("xxx")`
    var isValidBigInt: Bool {
        let range = NSRange(location: 0, length: utf16.count)
        return String.regexToCheckIsValidBigInt.firstMatch(in: self, options: [], range: range) != nil
    }
}

