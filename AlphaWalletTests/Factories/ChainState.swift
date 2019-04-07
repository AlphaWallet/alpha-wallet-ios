// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet

extension ChainState {
    static func make(
        config: Config = .make(),
        server: RPCServer = .main
    ) -> ChainState {
        return ChainState(config: config, server: server)
    }
}
