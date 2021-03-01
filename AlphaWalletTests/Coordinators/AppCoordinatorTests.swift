// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class AppCoordinatorTests: XCTestCase {

    func testStart() {
        do {
            let coordinator = try AppCoordinator(
                window: UIWindow(),
                analyticsService: FakeAnalyticsService(),
                keystore: FakeKeystore()
                    //hhh1 remove?
                //navigationController: FakeNavigationController()
            )

            coordinator.start()
            XCTAssertTrue(coordinator.navigationController.viewControllers[0] is UIViewController)
        } catch {
            XCTAssertThrowsError(error)
        }
    }

    func testStartWithAccounts() {
        do {
            let coordinator = try AppCoordinator(
                window: UIWindow(),
                analyticsService: FakeAnalyticsService(),
                keystore: FakeKeystore(
                    wallets: [.make()]
                ),
                navigationController: FakeNavigationController()
            )

            coordinator.start()

            XCTAssertEqual(3, coordinator.coordinators.count)
            XCTAssertTrue(coordinator.navigationController.viewControllers[0] is UITabBarController)
        } catch {
            XCTAssertThrowsError(error)
        }
    }

    func testReset() {
        do {
            let coordinator = try AppCoordinator(
                window: UIWindow(),
                analyticsService: FakeAnalyticsService(),
                keystore: FakeKeystore(
                    wallets: [.make()]
                )
            )
            coordinator.start()
            coordinator.reset()

            XCTAssertTrue(coordinator.navigationController.viewControllers[0] is CreateInitialWalletViewController)
        } catch {
            XCTAssertThrowsError(error)
        }
    }

    func testImportWalletCoordinator() {
        do {
            let coordinator = try AppCoordinator(
                window: UIWindow(),
                analyticsService: FakeAnalyticsService(),
                keystore: FakeKeystore(
                    wallets: [.make()]
                ),
                navigationController: FakeNavigationController()
            )
            coordinator.start()
            coordinator.showInitialWalletCoordinator()

            XCTAssertTrue(coordinator.navigationController.viewControllers[0] is CreateInitialWalletViewController)
        } catch {
            XCTAssertThrowsError(error)
        }
    }

    func testShowTransactions() {
        do {
            let coordinator = try AppCoordinator(
                window: UIWindow(),
                analyticsService: FakeAnalyticsService(),
                keystore: FakeKeystore(),
                navigationController: FakeNavigationController()
            )
            coordinator.start()

            coordinator.showTransactions(for: .make())

            XCTAssertEqual(3, coordinator.coordinators.count)
            XCTAssertTrue(coordinator.navigationController.viewControllers[0] is UITabBarController)
        } catch {
            XCTAssertThrowsError(error)
        }
    }

    func testHasInCoordinatorWithWallet() {
        do {
            let coordinator = try AppCoordinator(
                window: .init(),
                analyticsService: FakeAnalyticsService(),
                keystore: FakeKeystore(wallets: [.make()])
            )

            coordinator.start()

            XCTAssertNotNil(coordinator.inCoordinator)
        } catch {
            XCTAssertThrowsError(error)
        }
    }

    func testHasNoInCoordinatorWithoutWallets() {
        do {
            let coordinator = try AppCoordinator(
                window: .init(),
                analyticsService: FakeAnalyticsService(),
                keystore: FakeKeystore()
            )

            coordinator.start()

            XCTAssertNil(coordinator.inCoordinator)
        } catch {
            XCTAssertThrowsError(error)
        }
    }
}

class FakeAnalyticsService: AnalyticsServiceType {
    func log(action: AnalyticsAction, properties: [String : AnalyticsEventPropertyValue]?) { }
    func applicationDidBecomeActive() { }
    func application(continue userActivity: NSUserActivity) { }
    func application(open url: URL, sourceApplication: String?, annotation: Any) { }
    func application(open url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) { }
    func application(didReceiveRemoteNotification userInfo: [AnyHashable : Any]) { }
    func add(pushDeviceToken token: Data) { }
    func log(navigation: AnalyticsNavigation, properties: [String : AnalyticsEventPropertyValue]?) {}
    func setUser(property: AnalyticsUserProperty, value: AnalyticsEventPropertyValue) { }
    func incrementUser(property: AnalyticsUserProperty, by value: Int) { }
    func incrementUser(property: AnalyticsUserProperty, by value: Double) { }

    init() {}
}
