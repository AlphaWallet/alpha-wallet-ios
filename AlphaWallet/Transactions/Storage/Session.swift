// Copyright SIX DAY LLC. All rights reserved.

import Foundation

enum RefreshType {
    case balance
    case ethBalance
}

class WalletSession {
    let account: Wallet
    let server: RPCServer
    let tokenBalanceService: TokenBalanceService
    let config: Config
    let chainState: ChainState

    var sessionID: String {
        return Self.functional.sessionID(account: account, server: server)
    }

    init(
        account: Wallet,
        server: RPCServer,
        config: Config,
        tokenBalanceService: TokenBalanceService
    ) {
        self.account = account
        self.server = server
        self.config = config
        self.chainState = ChainState(config: config, server: server)
        self.tokenBalanceService = tokenBalanceService

        if config.development.isAutoFetchingDisabled {
            //no-op
        } else {
            self.chainState.start()
        }
    }

    func refresh(_ type: RefreshType) {
        switch type {
        case .balance:
            tokenBalanceService.refresh()
        case .ethBalance:
            tokenBalanceService.refreshEthBalance()
        }
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
