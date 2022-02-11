// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import RealmSwift

class TokenBalance: Object {
    @objc dynamic var balance = "0" {
        didSet {
            _nonFungibleBalance = balance.data(using: .utf8).flatMap { nonFungible(fromJsonData: $0) }
        }
    }
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
