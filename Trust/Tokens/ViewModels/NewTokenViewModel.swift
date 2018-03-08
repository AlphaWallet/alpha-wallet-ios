// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct NewTokenViewModel {
    var title: String {
        return NSLocalizedString("tokens.newtoken.navigation.title", value: "Add Custom Token", comment: "")
    }

    var stormBirdBalance: [UInt16] = []

    var displayStormBirdBalance: String {
        let stormBirdBalanceWithNoZeros = stormBirdBalance.filter { $0 != 0 }
        return (stormBirdBalanceWithNoZeros.map { String($0) }).joined(separator: ",")
    }

    var stormBirdBalanceAsInt16: [Int16] {
        return stormBirdBalance.map { Int16($0) }
    }

}
