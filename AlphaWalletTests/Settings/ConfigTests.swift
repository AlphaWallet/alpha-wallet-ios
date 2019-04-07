// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class ConfigTests: XCTestCase {
        
    func testChainIDDefault() {
        var config: Config = .make()

        XCTAssertEqual(1, config.chainID)
        XCTAssertEqual(.main, config.server)
    }

    //TODO remove when we support multi-chain
    func testChangeChainID() {
        XCTAssertEqual(1, Config.make().chainID)

        let testDefaults = UserDefaults.test
        Config.setChainId(RPCServer.ropsten.chainID, defaults: testDefaults)

        let config = Config(chainID: RPCServer.kovan.chainID)

        XCTAssertEqual(42, config.chainID)
        XCTAssertEqual(.kovan, config.server)
    }

    func testSwitchLocale() {
        var config: Config = .make()

        Config.setLocale(AppLocale.english)
        let vc1 = TokensViewController(
                session: .make(),
                account: .make(),
                dataStore: FakeTokensDataStore()
        )
        XCTAssertEqual(vc1.title, "Wallet")

        Config.setLocale(AppLocale.simplifiedChinese)
        let vc2 = TokensViewController(
                session: .make(),
                account: .make(),
                dataStore: FakeTokensDataStore()
        )
        XCTAssertEqual(vc2.title, "我的钱包")

        //Must change this back to system, otherwise other tests will break either immediately or the next run
        Config.setLocale(AppLocale.system)
    }

    func testNibsAccessAfterSwitchingLocale() {
        var config: Config = .make()

        Config.setLocale(AppLocale.english)
        Config.setLocale(AppLocale.simplifiedChinese)

        let tableView = UITableView()
        tableView.register(R.nib.bookmarkViewCell(), forCellReuseIdentifier: R.nib.bookmarkViewCell.name)
        XCTAssertNoThrow(tableView.dequeueReusableCell(withIdentifier: R.nib.bookmarkViewCell.name))

        //Must change this back to system, otherwise other tests will break either immediately or the next run
        Config.setLocale(AppLocale.system)
    }
}
