// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import RealmSwift
import BigInt

class TokenBalance: Object {
    
    @objc dynamic var backingBalance = "0"
    var balance: BigUInt {
        get {
            return BigUInt(Data(bytes: backingBalance.hexa2Bytes))
        } set {
            backingBalance = MarketQueueHandler.bytesToHexa(balance.serialize().array)
        }
    }

    convenience init(balance: BigUInt = BigUInt(0)) {
        self.init()
        self.balance = balance
    }

}
