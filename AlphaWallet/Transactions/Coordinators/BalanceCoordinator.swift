// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import APIKit
import JSONRPCKit
import Result
import BigInt

protocol BalanceCoordinatorType {
    var ethBalanceViewModel: BalanceBaseViewModel { get }
    var subscribableEthBalanceViewModel: Subscribable<BalanceBaseViewModel> { get }

    func refresh()
    func refreshEthBalance()

    // NOTE: only tests purposes
    func update()

    func coinTicker(_ addressAndRPCServer: AddressAndRPCServer) -> CoinTicker?
    func subscribableTokenBalance(_ addressAndRPCServer: AddressAndRPCServer) -> Subscribable<BalanceBaseViewModel>
}

class BalanceCoordinator: NSObject, BalanceCoordinatorType {
    private let wallet: Wallet
    private let server: RPCServer

    var ethBalanceViewModel: BalanceBaseViewModel {
        if let value = privateSubscribableViewModel.value {
            return value
        } else {
            return NativecryptoBalanceViewModel(server: server, balance: Balance(value: .zero), ticker: nil)
        }
    }

    lazy private (set) var subscribableEthBalanceViewModel: Subscribable<BalanceBaseViewModel> = .init(ethBalanceViewModel)

    lazy private var privateSubscribableViewModel: Subscribable<BalanceBaseViewModel> = {
        let etherToken = MultipleChainsTokensDataStore.functional.etherToken(forServer: server).addressAndRPCServer
        return subscribableTokenBalance(etherToken)
    }()

    private let walletBalanceCoordinator: WalletBalanceCoordinatorType
    private var balanceSubscriptionKey: Subscribable<BalanceBaseViewModel>.SubscribableKey?
    
    init(wallet: Wallet, server: RPCServer, walletBalanceCoordinator: WalletBalanceCoordinatorType) {
        self.wallet = wallet
        self.server = server
        self.walletBalanceCoordinator = walletBalanceCoordinator

        super.init()

        balanceSubscriptionKey = privateSubscribableViewModel.subscribe { [weak subscribableEthBalanceViewModel] viewModel in
            DispatchQueue.main.async {
                subscribableEthBalanceViewModel?.value = viewModel
            }
        }
    }

    func coinTicker(_ addressAndRPCServer: AddressAndRPCServer) -> CoinTicker? {
        subscribableTokenBalance(addressAndRPCServer).value?.ticker
    }

    func subscribableTokenBalance(_ addressAndRPCServer: AddressAndRPCServer) -> Subscribable<BalanceBaseViewModel> {
        walletBalanceCoordinator.subscribableTokenBalance(addressAndRPCServer: addressAndRPCServer)
    }

    deinit {
        balanceSubscriptionKey.flatMap { privateSubscribableViewModel.unsubscribe($0) }
    }

    func refresh() {
        walletBalanceCoordinator.refreshBalance().done { _ in

        }.cauterize()
    }
    func refreshEthBalance() {
        walletBalanceCoordinator.refreshEthBalance().done { _ in

        }.cauterize()
    }

    func update() {
        // NOTE: update method to refresh subscribable view model, only tests purposes
        subscribableEthBalanceViewModel.value = ethBalanceViewModel
    }
}
