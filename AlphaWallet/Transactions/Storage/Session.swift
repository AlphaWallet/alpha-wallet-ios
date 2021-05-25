// Copyright SIX DAY LLC. All rights reserved.

import Foundation

enum RefreshType {
    case balance
    case ethBalance
}

class WalletSession {
    let account: Wallet
    let server: RPCServer
    var balanceCoordinator: BalanceCoordinatorType
    let config: Config
    let chainState: ChainState
    var balance: Balance? {
        return balanceCoordinator.balance
    }

    var sessionID: String {
        return "\(account.address.eip55String.lowercased())-\(server.chainID)"
    }

    var balanceViewModel: Subscribable<BalanceBaseViewModel> = Subscribable(nil)

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
        self.balanceCoordinator.delegate = self


        if config.isAutoFetchingDisabled {
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

extension WalletSession: BalanceCoordinatorDelegate {
    func didUpdate(viewModel: BalanceViewModel) {
        balanceViewModel.value = viewModel
    }
}
