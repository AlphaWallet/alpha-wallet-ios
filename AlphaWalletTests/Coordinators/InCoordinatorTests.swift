// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import TrustKeystore

class InCoordinatorTests: XCTestCase {
    
    func testShowTabBar() {
        let config: Config = .make()
        let wallet: Wallet = .make()

        let coordinator = InCoordinator(
            navigationController: FakeNavigationController(),
            wallet: .make(),
            keystore: FakeKeystore(wallets: [wallet]),
            assetDefinitionStore: AssetDefinitionStore(),
            config: config
        )

        coordinator.start()

        let tabbarController = coordinator.navigationController.viewControllers[0] as? UITabBarController

        XCTAssertNotNil(tabbarController)

        XCTAssert(tabbarController?.viewControllers!.count == 4)
        XCTAssert((tabbarController?.viewControllers?[0] as? UINavigationController)?.viewControllers[0] is TokensViewController)
        XCTAssert((tabbarController?.viewControllers?[1] as? UINavigationController)?.viewControllers[0] is TransactionsViewController)
        XCTAssert((tabbarController?.viewControllers?[2] as? UINavigationController)?.viewControllers[0] is DappsHomeViewController)
        XCTAssert((tabbarController?.viewControllers?[3] as? UINavigationController)?.viewControllers[0] is SettingsViewController)
    }

    func testChangeRecentlyUsedAccount() {
        let account1: Wallet = .make(type: .watch(AlphaWallet.Address(string: "0x1000000000000000000000000000000000000000")!))
        let account2: Wallet = .make(type: .watch(AlphaWallet.Address(string: "0x2000000000000000000000000000000000000000")!))

        let keystore = FakeKeystore(
            wallets: [
                account1,
                account2
            ]
        )
        let coordinator = InCoordinator(
            navigationController: FakeNavigationController(),
            wallet: .make(),
            keystore: keystore,
            assetDefinitionStore: AssetDefinitionStore(),
            config: .make()
        )

        coordinator.showTabBar(for: account1)

        XCTAssertEqual(coordinator.keystore.recentlyUsedWallet, account1)

        coordinator.showTabBar(for: account2)

        XCTAssertEqual(coordinator.keystore.recentlyUsedWallet, account2)
    }

    func testShowSendFlow() {
        let wallet: Wallet = .make()
        let coordinator = InCoordinator(
                navigationController: FakeNavigationController(),
                wallet: wallet,
                keystore: FakeKeystore(wallets: [wallet]),
                assetDefinitionStore: AssetDefinitionStore(),
                config: .make()
        )
        coordinator.showTabBar(for: .make())

        coordinator.showPaymentFlow(for: .send(type: .nativeCryptocurrency(server: .main, destination: .none, amount: nil)), server: .main)

        let controller = (coordinator.navigationController.presentedViewController as? UINavigationController)?.viewControllers[0]

        XCTAssertTrue(coordinator.coordinators.last is PaymentCoordinator)
        XCTAssertTrue(controller is SendViewController)
    }

    func testShowRequstFlow() {
        let wallet: Wallet = .make()
        let coordinator = InCoordinator(
            navigationController: FakeNavigationController(),
            wallet: wallet,
            keystore: FakeKeystore(wallets: [wallet]),
            assetDefinitionStore: AssetDefinitionStore(),
            config: .make()
        )
        coordinator.showTabBar(for: .make())

        coordinator.showPaymentFlow(for: .request, server: .main)

        let controller = (coordinator.navigationController.presentedViewController as? UINavigationController)?.viewControllers[0]

        XCTAssertTrue(coordinator.coordinators.last is PaymentCoordinator)
        XCTAssertTrue(controller is RequestViewController)
    }

    func testShowTabDefault() {
        let coordinator = InCoordinator(
            navigationController: FakeNavigationController(),
            wallet: .make(),
            keystore: FakeKeystore(),
            assetDefinitionStore: AssetDefinitionStore(),
            config: .make()
        )
        coordinator.showTabBar(for: .make())

        let viewController = (coordinator.tabBarController?.selectedViewController as? UINavigationController)?.viewControllers[0]

        XCTAssert(viewController is TokensViewController)
    }

	//Commented out because the tokens tab has been moved to be under the More tab and will be moved
//    func testShowTabTokens() {
//        let coordinator = InCoordinator(
//            navigationController: FakeNavigationController(),
//            wallet: .make(),
//            keystore: FakeEtherKeystore(),
//            config: .make()
//        )
//        coordinator.showTabBar(for: .make())

//        coordinator.showTab(.tokens)

//        let viewController = (coordinator.tabBarController?.selectedViewController as? UINavigationController)?.viewControllers[0]

//        XCTAssert(viewController is TokensViewController)
//    }

    func testShowTabAlphwaWalletWallet() {
        let keystore = FakeEtherKeystore()
        switch keystore.createAccount() {
        case .success(let account):
            let wallet = Wallet(type: .real(account))
            keystore.recentlyUsedWallet = wallet
            let coordinator = InCoordinator(
                    navigationController: FakeNavigationController(),
                    wallet: wallet,
                    keystore: keystore,
                    assetDefinitionStore: AssetDefinitionStore(),
                    config: .make()
            )
            coordinator.showTabBar(for: wallet)

            coordinator.showTab(.wallet)

            let viewController = (coordinator.tabBarController?.selectedViewController as? UINavigationController)?.viewControllers[0]

            XCTAssert(viewController is TokensViewController)
        case .failure:
            XCTFail()
        }
    }
}
