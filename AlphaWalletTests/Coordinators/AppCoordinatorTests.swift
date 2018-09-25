// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import Trust

class AppCoordinatorTests: XCTestCase {
    
    func testStart() {
        let coordinator = AppCoordinator(
            window: UIWindow(),
            keystore: FakeKeystore()
        )
        
        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is WelcomeViewController)
    }
    
    func testStartWithAccounts() {
        let coordinator = AppCoordinator(
            window: UIWindow(),
            keystore: FakeKeystore(
                wallets: [.make()]
            )
        )
        
        coordinator.start()

        XCTAssertEqual(3, coordinator.coordinators.count)
        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is UITabBarController)
    }
    
    func testReset() {
        let coordinator = AppCoordinator(
            window: UIWindow(),
            keystore: FakeKeystore(
                wallets: [.make()]
            )
        )
        coordinator.start()
        
        coordinator.reset()
        
        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is WelcomeViewController)
    }

    func testStartWelcomeWalletCoordinator() {
        let coordinator = AppCoordinator(
            window: UIWindow(),
            keystore: FakeKeystore(),
            navigationController: FakeNavigationController()
        )
        coordinator.start()
        
        coordinator.showInitialWalletCoordinator(entryPoint: .welcome)
        
        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is WelcomeViewController)
    }

    func testImportWalletCoordinator() {
        let coordinator = AppCoordinator(
            window: UIWindow(),
            keystore: FakeKeystore(
                wallets: [.make()]
            ),
            navigationController: FakeNavigationController()
        )
        coordinator.start()
        coordinator.showInitialWalletCoordinator(entryPoint: .importWallet)

        XCTAssertTrue((coordinator.navigationController.presentedViewController as? UINavigationController)?.viewControllers[0] is ImportWalletViewController)
    }

    func testShowTransactions() {
        let coordinator = AppCoordinator(
            window: UIWindow(),
            keystore: FakeKeystore(),
            navigationController: FakeNavigationController()
        )
        coordinator.start()
        
        coordinator.showTransactions(for: .make())

        XCTAssertEqual(3, coordinator.coordinators.count)
        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is UITabBarController)
    }

    func testHasInCoordinatorWithWallet() {
        let coordinator = AppCoordinator(
                window: UIWindow(),
                keystore: FakeKeystore(
                        wallets: [.make()]
                )
        )

        coordinator.start()

        XCTAssertNotNil(coordinator.inCoordinator)
    }

    func testHasNoInCoordinatorWithoutWallets() {
        let coordinator = AppCoordinator(
                window: UIWindow(),
                keystore: FakeKeystore()
        )

        coordinator.start()

        XCTAssertNil(coordinator.inCoordinator)
    }
}
