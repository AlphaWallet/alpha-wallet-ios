// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import APIKit
import JSONRPCKit
import Result
import BigInt

protocol BalanceCoordinatorDelegate: AnyObject {
    func didUpdate(viewModel: BalanceViewModel)
}

protocol BalanceCoordinatorType {
    var balance: Balance? { get }
    var currencyRate: CurrencyRate? { get }
    var delegate: BalanceCoordinatorDelegate? { get set }
    var viewModel: BalanceViewModel { get }

    func refresh()
    func refreshEthBalance()
    func update()
}

class BalanceCoordinator: BalanceCoordinatorType {
    private let wallet: Wallet
    private let server: RPCServer
    private let storage: TokensDataStore

    var balance: Balance?
    var currencyRate: CurrencyRate?
    weak var delegate: BalanceCoordinatorDelegate?

    var viewModel: BalanceViewModel {
        return BalanceViewModel(
            server: server,
            balance: balance,
            rate: currencyRate
        )
    }

    init(
            wallet: Wallet,
            server: RPCServer,
            storage: TokensDataStore
    ) {
        self.wallet = wallet
        self.server = server
        self.storage = storage
        
        //Since this is called at launch, we don't want it to block launching
        DispatchQueue.global().async {
            DispatchQueue.main.async { [weak storage] in
                storage?.refreshBalance()
            }
        }

        storage.tokensModel.subscribe { [weak self, weak storage] tokensModel in
            let etherToken = TokensDataStore.etherToken(forServer: server)
            guard let tokens = tokensModel, let eth = tokens.first(where: { $0 == etherToken }) else {
                return
            }

            let ticker = storage?.coinTicker(for: eth)
            self?.balance = Balance(value: BigInt(eth.value, radix: 10) ?? BigInt(0))
            self?.currencyRate = ticker?.rate
            self?.update()
        }
    }

    deinit {
        print("\(self).deinit")
    }

    func refresh() {
        storage.refreshBalance()
    }
    func refreshEthBalance() {
        storage.refreshETHBalance()
    }
    func update() {
        delegate?.didUpdate(viewModel: viewModel)
    }
}
