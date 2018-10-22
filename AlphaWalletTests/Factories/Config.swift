// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet

extension Config {
    static func make(
        defaults: UserDefaults = .test
    ) -> Config {
        return Config(
            defaults: defaults
        )
    }
}
