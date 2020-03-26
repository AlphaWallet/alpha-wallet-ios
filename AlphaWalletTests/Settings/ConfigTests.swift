// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class ConfigTests: XCTestCase {

    //This is still used by Dapp browser
    func testChangeChainID() {
        let testDefaults = UserDefaults.test
        XCTAssertEqual(1, Config.getChainId(defaults: testDefaults))
        Config.setChainId(RPCServer.ropsten.chainID, defaults: testDefaults)
        XCTAssertEqual(RPCServer.ropsten.chainID, Config.getChainId(defaults: testDefaults))
    }

    func testSwitchLocale() {
        let assetDefinitionStore = AssetDefinitionStore()
        var sessions = ServerDictionary<WalletSession>()
        sessions[.main] = WalletSession.make()
        Config.setLocale(AppLocale.english)
        let vc1 = TokensViewController(
                sessions: sessions,
                account: .make(),
                tokenCollection: .init(filterTokensCoordinator: FilterTokensCoordinator(assetDefinitionStore: assetDefinitionStore), tokenDataStores: [FakeTokensDataStore()]),
                assetDefinitionStore: assetDefinitionStore,
                eventsDataStore: FakeEventsDataStore(),
                filterTokensCoordinator: FilterTokensCoordinator(assetDefinitionStore: assetDefinitionStore)
        )
        XCTAssertEqual(vc1.title, "Wallet")

        Config.setLocale(AppLocale.simplifiedChinese)
        let vc2 = TokensViewController(
                sessions: sessions,
                account: .make(),
                tokenCollection: .init(filterTokensCoordinator: FilterTokensCoordinator(assetDefinitionStore: assetDefinitionStore), tokenDataStores: [FakeTokensDataStore()]),
                assetDefinitionStore: assetDefinitionStore,
                eventsDataStore: FakeEventsDataStore(),
                filterTokensCoordinator: FilterTokensCoordinator(assetDefinitionStore: assetDefinitionStore)
        )
        XCTAssertEqual(vc2.title, "我的钱包")

        //Must change this back to system, otherwise other tests will break either immediately or the next run
        Config.setLocale(AppLocale.system)
    }

    func testNibsAccessAfterSwitchingLocale() {
        Config.setLocale(AppLocale.english)
        Config.setLocale(AppLocale.simplifiedChinese)

        let tableView = UITableView()
        tableView.register(R.nib.bookmarkViewCell(), forCellReuseIdentifier: R.nib.bookmarkViewCell.name)
        XCTAssertNoThrow(tableView.dequeueReusableCell(withIdentifier: R.nib.bookmarkViewCell.name))

        //Must change this back to system, otherwise other tests will break either immediately or the next run
        Config.setLocale(AppLocale.system)
    }
}
