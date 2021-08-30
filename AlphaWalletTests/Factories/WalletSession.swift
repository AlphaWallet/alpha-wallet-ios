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

    var ethBalanceViewModel: BalanceBaseViewModel {
        NativecryptoBalanceViewModel(server: .main, balance: balance ?? Balance(value: .zero), ticker: nil)
    }
    var subscribableEthBalanceViewModel: Subscribable<BalanceBaseViewModel> = .init(nil)

    func refresh() {

    }
    func refreshEthBalance() {

    }

    // NOTE: only tests purposes
    func update() {
        subscribableEthBalanceViewModel.value = ethBalanceViewModel
    }

    func coinTicker(_ addressAndRPCServer: AddressAndRPCServer) -> CoinTicker? {
        return nil
    }
    func subscribableTokenBalance(_ addressAndRPCServer: AddressAndRPCServer) -> Subscribable<BalanceBaseViewModel> {
        return .init(nil)
    }

    static func make() -> FakeBalanceCoordinator {
        return .init()
    }
}
