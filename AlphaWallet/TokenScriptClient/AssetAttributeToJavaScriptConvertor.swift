// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

struct AssetAttributeToJavaScriptConvertor {
    //Numbers must be formatted as string (or maybe later a suitable JavaScript big number type), but not as numbers in JavaScript because they can lose precision
    func formatAsTokenScriptJavaScript(value: AssetInternalValue) -> String? {
        switch value {
        case .address(let address):
            return "\"\(address.eip55String)\""
        case .string(let string):
            return "\"\(string)\""
        case .int(let int):
            return "\"\(String(int))\""
        case .uint(let uint):
            return "\"\(String(uint))\""
        case .generalisedTime(let generalisedTime):
            return generalisedTime.formatAsTokenScriptJavaScript
        case .bool(let bool):
            return bool ? "true" : "false"
        case .subscribable, .openSeaNonFungibleTraits:
            return nil
        }
    }
}
