// Copyright SIX DAY LLC. All rights reserved.

import Foundation

enum RefreshType {
    case balance
    case ethBalance
}

class WalletSession {
    let account: Wallet
    let server: RPCServer
    let balanceCoordinator: BalanceCoordinator
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
        tokensDataStore: TokensDataStore
    ) {
        self.account = account
        self.server = server
        self.config = config
        self.chainState = ChainState(config: config, server: server)
        self.balanceCoordinator = BalanceCoordinator(wallet: account, server: server, storage: tokensDataStore)
        self.balanceCoordinator.delegate = self

        self.chainState.start()
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
