// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct NewTokenViewModel {
    var title: String {
        return NSLocalizedString("tokens.newtoken.navigation.title", value: "Add Custom Token", comment: "")
    }

    var stormBirdBalance: [String] = []

    var stormBirdBalanceAsInt: Int {
        var balance = 0
        if !stormBirdBalance.isEmpty {
            for i in 0...stormBirdBalance.count - 1 {
                if Int(stormBirdBalance[i], radix: 16)! > 0 {
                    balance += 1
                }
            }
        }
        return balance
    }

}
