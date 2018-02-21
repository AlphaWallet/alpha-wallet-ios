// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import RealmSwift

class TokenBalance: Object {
    @objc dynamic var balance: Int16 = 0
    
    convenience init(balance: Int16 = 0) {
        self.init()
        self.balance = balance
    }

}
