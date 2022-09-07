// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import AlphaWalletOpenSea
import RealmSwift

public struct TokenBalanceValue {
    let json: String
    let balance: String
    let nonFungibleBalance: NonFungibleFromJson?
}

extension TokenBalanceValue: Hashable {
    init(balance: TokenBalance) {
        self.json = balance.json
        self.balance = balance.balance
        self.nonFungibleBalance = balance.nonFungibleBalance
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(json)
        hasher.combine(balance)
    }
}

class TokenBalance: Object {
    @objc dynamic var balance = "0" {
        didSet {
            _nonFungibleBalance = balance.data(using: .utf8).flatMap { nonFungible(fromJsonData: $0) }
        }
    }
    //NOTE: Check if its still using
    @objc dynamic var json: String = "{}"

    convenience init(balance: String = "0", json: String = "{}") {
        self.init()
        self.balance = balance
        self.json = json
    }

    private var _nonFungibleBalance: NonFungibleFromJson?

    var nonFungibleBalance: NonFungibleFromJson? {
        if let _openSeaNonFungible = _nonFungibleBalance {
            return _openSeaNonFungible
        } else {
            let nonFungibleBalance = balance.data(using: .utf8).flatMap { nonFungible(fromJsonData: $0) }

            _nonFungibleBalance = nonFungibleBalance
            return nonFungibleBalance
        }
    }

    override static func ignoredProperties() -> [String] {
        return ["openSeaNonFungible", "_openSeaNonFungible"]
    }
}

extension TokenBalanceValue: Equatable {
    public static func == (lhs: TokenBalanceValue, rhs: TokenBalanceValue) -> Bool {
        return lhs.json == rhs.json && lhs.balance == rhs.balance
    }

}
