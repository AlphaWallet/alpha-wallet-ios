// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

extension ServerDictionary {
    static func make(server: RPCServer = .main) -> ServerDictionary<WalletSession> {
        var sessons: ServerDictionary<WalletSession> = .init()
        sessons[.main] = WalletSession.make()
        return sessons
    }
}

class SettingsCoordinatorTests: XCTestCase {
    func testOnDeleteCleanStorage() {
        class Delegate: SettingsCoordinatorDelegate, CanOpenURL {
            var deleteDelegateMethodCalled = false

            func didRestart(with account: Wallet, in coordinator: SettingsCoordinator, reason: RestartReason) {}
            func didUpdateAccounts(in coordinator: SettingsCoordinator) {}
            func didCancel(in coordinator: SettingsCoordinator) {}
            func didPressShowWallet(in coordinator: SettingsCoordinator) {}
            func assetDefinitionsOverrideViewController(for: SettingsCoordinator) -> UIViewController? { return nil }
            func showConsole(in coordinator: SettingsCoordinator) {}
            func delete(account: Wallet, in coordinator: SettingsCoordinator) {
                deleteDelegateMethodCalled = true
            }
            func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {}
            func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {}
            func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {}
            func restartToAddEnableAndSwitchBrowserToServer(in coordinator: SettingsCoordinator) {}
            func restartToRemoveServer(in coordinator: SettingsCoordinator) {}
        }

        let storage = FakeTransactionsStorage(server: .main)
        let promptBackupCoordinator = PromptBackupCoordinator(keystore: FakeKeystore(), wallet: .make(), config: .make(), analyticsCoordinator: FakeAnalyticsService())
        let sessons = ServerDictionary<Any>.make(server: .main)

        let walletConnectCoordinator = WalletConnectCoordinator(keystore: FakeKeystore(), sessions: sessons, navigationController: FakeNavigationController(), analyticsCoordinator: FakeAnalyticsService(), config: .make(), nativeCryptoCurrencyPrices: .init())
        let coordinator = SettingsCoordinator(
            navigationController: FakeNavigationController(),
            keystore: FakeEtherKeystore(),
            config: .make(),
            sessions: sessons,
            restartQueue: .init(),
            promptBackupCoordinator: promptBackupCoordinator,
            analyticsCoordinator: FakeAnalyticsService(),
            walletConnectCoordinator: walletConnectCoordinator,
            walletBalanceCoordinator: FakeWalletBalanceCoordinator()
        )
        let delegate = Delegate()
        coordinator.delegate = delegate
        storage.add([.make()])

        XCTAssertEqual(1, storage.count)

        let accountCoordinator = AccountsCoordinator(
            config: .make(),
            navigationController: FakeNavigationController(),
            keystore: FakeEtherKeystore(),
            promptBackupCoordinator: promptBackupCoordinator,
            analyticsCoordinator: FakeAnalyticsService(),
            viewModel: .init(configuration: .changeWallets),
            walletBalanceCoordinator: FakeWalletBalanceCoordinator()
        )

        XCTAssertFalse(delegate.deleteDelegateMethodCalled)
        coordinator.didDeleteAccount(account: .make(), in: accountCoordinator)
        XCTAssertTrue(delegate.deleteDelegateMethodCalled)

//        XCTAssertEqual(0, storage.count)
    }
}

import PromiseKit

final class FakeWalletBalanceCoordinator: WalletBalanceCoordinatorType {
    var subscribableWalletsSummary: Subscribable<WalletSummary> = .init(nil)
    typealias Services = (TokensDataStore, TransactionsStorage)
    private var services: ServerDictionary<Services> = ServerDictionary<Services>.init()

    init(config: Config = .make(), account: Wallet = .make()) {
        for each in config.enabledServers {
            services[each] = (
                FakeTokensDataStore(account: account, server: each),
                FakeTransactionsStorage(server: each)
            )
        }
    }

    func subscribableWalletBalance(wallet: Wallet) -> Subscribable<WalletBalance> {
        return .init(nil)
    }

    func subscribableTokenBalance(addressAndRPCServer: AddressAndRPCServer) -> Subscribable<BalanceBaseViewModel> {
        return .init(nil)
    }

    func start() {

    }

    func refreshBalance() -> Promise<Void> {
        return .value(())
    }

    func refreshEthBalance() -> Promise<Void> {
        return .value(())
    }

    func refreshBalance(updatePolicy: PrivateBalanceFetcher.RefreshBalancePolicy, force: Bool) -> Promise<Void> {
        return .value(())
    }
    
    func transactionsStorage(wallet: Wallet, server: RPCServer) -> TransactionsStorage {
        services[server].1
    }

    func tokensDatastore(wallet: Wallet, server: RPCServer) -> TokensDataStore {
        services[server].0
    }
}
