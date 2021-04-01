// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet

extension WalletSession {
    static func make(
        account: Wallet = .make(),
        server: RPCServer = .main,
        config: Config = .make(),
        balanceCoordinator: BalanceCoordinatorType = FakeBalanceCoordinator()
    ) -> WalletSession {
        return WalletSession(
            account: account,
            server: server,
            config: config,
            balanceCoordinator: balanceCoordinator
        )
    }

    static func makeStormBirdSession(
        account: Wallet = .makeStormBird(),
        server: RPCServer,
        config: Config = .make(),
        balanceCoordinator: BalanceCoordinatorType = FakeBalanceCoordinator()
    ) -> WalletSession {
        return WalletSession(
            account: account,
            server: server,
            config: config,
            balanceCoordinator: balanceCoordinator
        )
    }
}

class FakeBalanceCoordinator: BalanceCoordinatorType {
    var balance: Balance? = nil {
        didSet {
            update()
        }
    }

    var currencyRate: CurrencyRate?

    weak var delegate: BalanceCoordinatorDelegate?

    var viewModel: BalanceViewModel {
        .init(server: .main, balance: balance, rate: currencyRate)
    }

    func refresh() {
        update()
    }

    func refreshEthBalance() {
        update()
    }

    func update() {
        delegate?.didUpdate(viewModel: viewModel)
    }

    static func make() -> FakeBalanceCoordinator {
        return .init()
    }
}
