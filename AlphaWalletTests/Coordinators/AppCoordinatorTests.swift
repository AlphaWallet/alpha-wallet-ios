// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

extension KeychainStorage {
    static func make() -> KeychainStorage {
        let uniqueString = NSUUID().uuidString
        return try! .init(keyPrefix: "fake" + uniqueString)
    }
}

class AppCoordinatorTests: XCTestCase {

    func testStart() {
        do {
            let coordinator = try AppCoordinator(
                window: UIWindow(),
                analytics: FakeAnalyticsService(),
                keystore: FakeEtherKeystore(),
                walletAddressesStore: fakeWalletAddressesStore(wallets: [.make()]), securedStorage: KeychainStorage.make())

            XCTAssertTrue(coordinator.navigationController.viewControllers[0].isSplashScreen)
            coordinator.start()
            XCTAssertTrue(coordinator.navigationController.viewControllers[0] is CreateInitialWalletViewController)
        } catch {
            XCTAssertThrowsError(error)
        }
    }

    func testStartWithAccounts() {
        do {
            let coordinator = try AppCoordinator(
                window: UIWindow(),
                analytics: FakeAnalyticsService(),
                keystore: FakeEtherKeystore(
                    wallets: [.make()],
                    recentlyUsedWallet: .make()
                ),
                walletAddressesStore: fakeWalletAddressesStore(wallets: [.make()]),
                navigationController: FakeNavigationController(), securedStorage: KeychainStorage.make()
            )

            coordinator.start()

            XCTAssertEqual(4, coordinator.coordinators.count)

            XCTAssertTrue(coordinator.navigationController.viewControllers[0] is AccountsViewController)
            XCTAssertTrue(coordinator.navigationController.viewControllers[1] is UITabBarController)
        } catch {
            XCTAssertThrowsError(error)
        }
    }

    func testReset() {
        do {
            let coordinator = try AppCoordinator(
                window: UIWindow(),
                analytics: FakeAnalyticsService(),
                keystore: FakeEtherKeystore(
                    wallets: [.make()],
                    recentlyUsedWallet: .make()
                ),
                walletAddressesStore: fakeWalletAddressesStore(wallets: [.make()]), securedStorage: KeychainStorage.make()
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
                analytics: FakeAnalyticsService(),
                keystore: FakeEtherKeystore(
                    wallets: [.make()],
                    recentlyUsedWallet: .make()
                ),
                walletAddressesStore: fakeWalletAddressesStore(wallets: [.make()]),
                navigationController: FakeNavigationController(), securedStorage: KeychainStorage.make()
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
                analytics: FakeAnalyticsService(),
                keystore: FakeEtherKeystore(
                    wallets: [.make()],
                    recentlyUsedWallet: .make()
                ),
                walletAddressesStore: fakeWalletAddressesStore(wallets: [.make()]),
                navigationController: FakeNavigationController(), securedStorage: KeychainStorage.make()
            )
            coordinator.start()

            coordinator.showActiveWallet(for: .make(), animated: true)

            XCTAssertEqual(6, coordinator.coordinators.count)
            XCTAssertTrue(coordinator.navigationController.viewControllers[0] is AccountsViewController)
            XCTAssertTrue(coordinator.navigationController.viewControllers[1] is UITabBarController)
        } catch {
            XCTAssertThrowsError(error)
        }
    }

    func testHasInCoordinatorWithWallet() {
        do {
            let coordinator = try AppCoordinator(
                window: .init(),
                analytics: FakeAnalyticsService(),
                keystore: FakeEtherKeystore(
                    wallets: [.make()],
                    recentlyUsedWallet: .make()
                ),
                walletAddressesStore: fakeWalletAddressesStore(wallets: [.make()]), securedStorage: KeychainStorage.make()
            )

            coordinator.start()

            XCTAssertNotNil(coordinator.activeWalletCoordinator)
        } catch {
            XCTAssertThrowsError(error)
        }
    }

    func testHasNoInCoordinatorWithoutWallets() {
        do {
            let coordinator = try AppCoordinator(
                window: .init(),
                analytics: FakeAnalyticsService(),
                keystore: FakeEtherKeystore(),
                walletAddressesStore: fakeWalletAddressesStore(wallets: [.make()]), securedStorage: KeychainStorage.make())

            coordinator.start()

            XCTAssertNil(coordinator.activeWalletCoordinator)
        } catch {
            XCTAssertThrowsError(error)
        }
    }
}

class FakeAnalyticsService: AnalyticsServiceType {
    func log(action: AnalyticsAction, properties: [String: AnalyticsEventPropertyValue]?) { }
    func log(error: AnalyticsError, properties: [String: AnalyticsEventPropertyValue]?) { }
    func log(stat: AnalyticsStat, properties: [String: AnalyticsEventPropertyValue]?) {}
    func applicationDidBecomeActive() { }
    func application(continue userActivity: NSUserActivity) { }
    func application(open url: URL, sourceApplication: String?, annotation: Any) { }
    func application(open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) { }
    func application(didReceiveRemoteNotification userInfo: [AnyHashable: Any]) { }
    func log(navigation: AnalyticsNavigation, properties: [String: AnalyticsEventPropertyValue]?) {}
    func setUser(property: AnalyticsUserProperty, value: AnalyticsEventPropertyValue) { }
    func incrementUser(property: AnalyticsUserProperty, by value: Int) { }
    func incrementUser(property: AnalyticsUserProperty, by value: Double) { }

    init() {}
}
