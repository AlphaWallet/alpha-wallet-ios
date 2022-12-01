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
        let coordinator = AppCoordinator(
            window: UIWindow(),
            analytics: FakeAnalyticsService(),
            keystore: FakeEtherKeystore(),
            walletAddressesStore: fakeWalletAddressesStore(wallets: [.make()]),
            navigationController: FakeNavigationController(),
            securedStorage: KeychainStorage.make(),
            legacyFileBasedKeystore: .make())

        XCTAssertTrue(coordinator.navigationController.viewControllers[0].isSplashScreen)
        coordinator.start()
        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is CreateInitialWalletViewController)
    }

    func testStartWithAccounts() {
        let coordinator = AppCoordinator(
            window: UIWindow(),
            analytics: FakeAnalyticsService(),
            keystore: FakeEtherKeystore(
                wallets: [.make()],
                recentlyUsedWallet: .make()
            ),
            walletAddressesStore: fakeWalletAddressesStore(wallets: [.make()]),
            navigationController: FakeNavigationController(),
            securedStorage: KeychainStorage.make(),
            legacyFileBasedKeystore: .make())

        coordinator.start()

        XCTAssertEqual(3, coordinator.coordinators.count)

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is AccountsViewController)
        XCTAssertTrue(coordinator.navigationController.viewControllers[1] is UITabBarController)
    }

    func testReset() {
        let coordinator = AppCoordinator(
            window: UIWindow(),
            analytics: FakeAnalyticsService(),
            keystore: FakeEtherKeystore(
                wallets: [.make()],
                recentlyUsedWallet: .make()
            ),
            walletAddressesStore: fakeWalletAddressesStore(wallets: [.make()]),
            navigationController: FakeNavigationController(),
            securedStorage: KeychainStorage.make(),
            legacyFileBasedKeystore: .make())
        coordinator.start()
        coordinator.reset()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is CreateInitialWalletViewController)
    }

    func testImportWalletCoordinator() {
        let coordinator = AppCoordinator(
            window: UIWindow(),
            analytics: FakeAnalyticsService(),
            keystore: FakeEtherKeystore(
                wallets: [.make()],
                recentlyUsedWallet: .make()
            ),
            walletAddressesStore: fakeWalletAddressesStore(wallets: [.make()]),
            navigationController: FakeNavigationController(),
            securedStorage: KeychainStorage.make(),
            legacyFileBasedKeystore: .make())

        coordinator.start()
        coordinator.showInitialWalletCoordinator()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is CreateInitialWalletViewController)
    }

    func testShowTransactions() {
        let coordinator = AppCoordinator(
            window: UIWindow(),
            analytics: FakeAnalyticsService(),
            keystore: FakeEtherKeystore(
                wallets: [.make()],
                recentlyUsedWallet: .make()
            ),
            walletAddressesStore: fakeWalletAddressesStore(wallets: [.make()]),
            navigationController: FakeNavigationController(),
            securedStorage: KeychainStorage.make(),
            legacyFileBasedKeystore: .make())
        coordinator.start()

        coordinator.showActiveWallet(for: .make(), animated: true)

        XCTAssertEqual(5, coordinator.coordinators.count)
        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is AccountsViewController)
        XCTAssertTrue(coordinator.navigationController.viewControllers[1] is UITabBarController)
    }

    func testHasInCoordinatorWithWallet() {
        let coordinator = AppCoordinator(
            window: .init(),
            analytics: FakeAnalyticsService(),
            keystore: FakeEtherKeystore(
                wallets: [.make()],
                recentlyUsedWallet: .make()
            ),
            walletAddressesStore: fakeWalletAddressesStore(wallets: [.make()]),
            navigationController: FakeNavigationController(),
            securedStorage: KeychainStorage.make(),
            legacyFileBasedKeystore: .make())

        coordinator.start()

        XCTAssertNotNil(coordinator.activeWalletCoordinator)
    }

    func testHasNoInCoordinatorWithoutWallets() {
        let coordinator = AppCoordinator(
            window: .init(),
            analytics: FakeAnalyticsService(),
            keystore: FakeEtherKeystore(),
            walletAddressesStore: fakeWalletAddressesStore(wallets: [.make()]),
            navigationController: FakeNavigationController(),
            securedStorage: KeychainStorage.make(),
            legacyFileBasedKeystore: .make())

        coordinator.start()

        XCTAssertNil(coordinator.activeWalletCoordinator)
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
