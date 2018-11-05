// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import RealmSwift

class TokenBalance: Object {
    @objc dynamic var balance = "0"
    @objc dynamic var json: String = "{}"

    convenience init(balance: String = "0", json: String = "{}") {
        self.init()
        self.balance = balance
        self.json = json
    }
}
