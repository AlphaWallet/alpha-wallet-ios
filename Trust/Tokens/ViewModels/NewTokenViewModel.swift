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
            for _ in 0...stormBirdBalance.count - 1 {
                balance += 1
            }
        }
        return balance
    }

}
