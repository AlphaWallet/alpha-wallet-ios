// Copyright SIX DAY LLC. All rights reserved.

import Foundation

enum RefreshType {
    case balance
    case ethBalance
}

class WalletSession {
    let account: Wallet
    let server: RPCServer
    let balanceCoordinator: BalanceCoordinatorType
    let config: Config
    let chainState: ChainState

    var sessionID: String {
        return Self.functional.sessionID(account: account, server: server)
    }

    init(
        account: Wallet,
        server: RPCServer,
        config: Config,
        balanceCoordinator: BalanceCoordinatorType
    ) {
        self.account = account
        self.server = server
        self.config = config
        self.chainState = ChainState(config: config, server: server)
        self.balanceCoordinator = balanceCoordinator

        if config.development.isAutoFetchingDisabled {
            //no-op
        } else {
            self.chainState.start()
        }
    }

    func refresh(_ type: RefreshType) {
        switch type {
        case .balance:
            balanceCoordinator.refresh()
        case .ethBalance:
            balanceCoordinator.refreshEthBalance()
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
