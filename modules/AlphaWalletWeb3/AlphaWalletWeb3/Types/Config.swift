// Copyright © 2023 Stormbird PTE. LTD.

import AlphaWalletCore
import BigInt

//TODO Some duplicated code from AlphaWalletFoundation
public struct Web3Config {
    public static var locale: Locale {
        if let identifier = getLocale(), isRunningTests() {
            return Locale(identifier: identifier)
        } else {
            return Locale.current
        }
    }

    fileprivate static func getLocale() -> String? {
        let defaults = UserDefaults.standardOrForTests
        return defaults.string(forKey: Keys.locale)
    }

    struct Keys {
        static let locale = "locale"
    }
}
