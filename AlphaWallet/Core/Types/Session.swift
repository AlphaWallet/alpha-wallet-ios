// Copyright SIX DAY LLC. All rights reserved.

import Foundation

class WalletSession {
    let account: Wallet
    let server: RPCServer
    let tokenBalanceService: TokenBalanceService
    let config: Config
    let chainState: ChainState
    let tokenProvider: TokenProviderType
    var sessionID: String {
        return WalletSession.functional.sessionID(account: account, server: server)
    }
    
    init(account: Wallet, server: RPCServer, config: Config, tokenBalanceService: TokenBalanceService) {
        self.account = account
        self.server = server
        self.config = config
        self.chainState = ChainState(config: config, server: server)
        self.tokenBalanceService = tokenBalanceService
        self.tokenProvider = TokenProvider(account: account, server: server)

        if config.development.isAutoFetchingDisabled {
            //no-op
        } else {
            self.chainState.start()
        }
    }

    func start() {
        tokenBalanceService.start()
    }

    func stop() {
        chainState.stop()
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
