// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import RealmSwift
import BigInt
import TrustKeystore

class TokenObject: Object {
    @objc dynamic var contract: String = ""
    @objc dynamic var name: String = ""
    @objc dynamic var symbol: String = ""
    @objc dynamic var decimals: Int = 0
    @objc dynamic var value: String = ""
    @objc dynamic var isDisabled: Bool = false
    @objc dynamic var isERC875: Bool = false
    var balance = List<TokenBalance>()
    enum TokenType: String {
        case erc20 = "ERC20"
        case erc875 = "ERC875"
    }
    @objc dynamic var rawType: String = TokenType.erc20.rawValue
    var type: TokenType {
        get {
            return TokenType(rawValue: rawType)!
        }
        set {
            rawType = newValue.rawValue
        }
    }
    
    var checkIfERC875: Bool {
        return type == .erc875
    }
    
    var isERC20: Bool {
        return type == .erc20
    }

    convenience init(
            contract: String = "",
            name: String = "",
            symbol: String = "",
            decimals: Int = 0,
            value: String,
            isCustom: Bool = false,
            isDisabled: Bool = false,
            isERC875: Bool = false
    ) {
        self.init()
        self.contract = contract
        self.name = name
        self.symbol = symbol
        self.decimals = decimals
        self.value = value
        self.isDisabled = isDisabled
        self.isERC875 = isERC875
    }

    var address: Address {
        return Address(string: contract)!
    }

    var valueBigInt: BigInt {
        return BigInt(value) ?? BigInt()
    }

    override static func primaryKey() -> String? {
        return "contract"
    }

    override static func ignoredProperties() -> [String] {
        return ["type"]
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? TokenObject else { return false }
        return object.contract == self.contract
    }

    var title: String {
        return name.isEmpty ? symbol : (name + " (" + symbol + ")")
    }
}
