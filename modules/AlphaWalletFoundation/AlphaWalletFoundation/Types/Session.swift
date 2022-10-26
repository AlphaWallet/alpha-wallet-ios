// Copyright SIX DAY LLC. All rights reserved.

import Foundation

extension WalletSession {
    public static func == (_ lhs: WalletSession, _ rhs: WalletSession) -> Bool {
        return lhs.server == rhs.server
    }
}

public final class WalletSession: Equatable {
    public let analytics: AnalyticsLogger
    public let account: Wallet
    public let server: RPCServer
    public let config: Config
    public let chainState: ChainState
    public lazy private (set) var tokenProvider: TokenProviderType = {
        return TokenProvider(account: account, server: server, analytics: analytics)
    }()
    public var sessionID: String {
        return WalletSession.functional.sessionID(account: account, server: server)
    }

    public init(account: Wallet, server: RPCServer, config: Config, analytics: AnalyticsLogger) {
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

    public func stop() {
        chainState.stop()
    }
}

extension WalletSession {
    public class functional {}
}

extension WalletSession.functional {
    public static func sessionID(account: Wallet, server: RPCServer) -> String {
        return "\(account.address.eip55String.lowercased())-\(server.chainID)"
    }
}
