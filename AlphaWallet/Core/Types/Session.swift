// Copyright SIX DAY LLC. All rights reserved.

import Foundation

extension WalletSession {
    static func == (_ lhs: WalletSession, _ rhs: WalletSession) -> Bool {
        return lhs.server == rhs.server
    }
}

class WalletSession: Equatable {
    let analytics: AnalyticsLogger
    let account: Wallet
    let server: RPCServer
    let config: Config
    let chainState: ChainState
    lazy private (set) var tokenProvider: TokenProviderType = {
        return TokenProvider(account: account, server: server, analytics: analytics, queue: queue)
    }()
    var sessionID: String {
        return WalletSession.functional.sessionID(account: account, server: server)
    }
    lazy private (set) var queue: DispatchQueue = {
        return DispatchQueue(label: "com.WalletSession.\(account.address.eip55String).\(server)")
    }()

    init(account: Wallet, server: RPCServer, config: Config, analytics: AnalyticsLogger) {
        self.analytics = analytics
        self.account = account
        self.server = server
        self.config = config
        self.chainState = ChainState(config: config, server: server, analytics: analytics)

        if config.development.isAutoFetchingDisabled {
            //no-op
        } else {
            self.chainState.start()
        }
    }

    func stop() {
        chainState.stop()
    }

}

extension WalletSession {
    var capi10Account: CAIP10Account {
        return CAIP10Account(blockchain: .init(server.eip155)!, address: account.address.eip55String)!
    }
}

extension WalletSession {
    class functional {}
}

extension WalletSession.functional {
    static func sessionID(account: Wallet, server: RPCServer) -> String {
        return "\(account.address.eip55String.lowercased())-\(server.chainID)"
    }
}
