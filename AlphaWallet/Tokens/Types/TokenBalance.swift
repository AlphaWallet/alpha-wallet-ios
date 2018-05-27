// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import RealmSwift
import BigInt

class TokenBalance: Object {
    
    @objc dynamic var balance = "0"

    convenience init(balance: String = "0") {
        self.init()
        self.balance = balance
    }

}
