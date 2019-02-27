// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet

extension Config {
    static func make(defaults: UserDefaults = .test) -> Config {
        //TODO perhaps we should be explicit about which chain the Config instance is for
        return Config(defaults: defaults)
    }
}
