// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet
import AlphaWalletFoundation

extension Config {
    static func make(defaults: UserDefaults = .test, enabledServers: [RPCServer] = [.main]) -> Config {
        //TODO perhaps we should be explicit about which chain the Config instance is for
        var config = Config(defaults: defaults)
        config.enabledServers = enabledServers

        return config
    }
}
