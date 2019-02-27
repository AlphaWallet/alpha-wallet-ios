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
        Config.setLocale(AppLocale.english)
        let vc1 = TokensViewController(
                sessions: .init(),
                account: .make(),
                tokenCollection: .init(tokenDataStores: [FakeTokensDataStore()])
        )
        XCTAssertEqual(vc1.title, "Wallet")

        Config.setLocale(AppLocale.simplifiedChinese)
        let vc2 = TokensViewController(
                sessions: .init(),
                account: .make(),
                tokenCollection: .init(tokenDataStores: [FakeTokensDataStore()])
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

    func testWeb3StillLoadsAfterSwitchingLocale() {
        Config.setLocale(AppLocale.english)
        Config.setLocale(AppLocale.simplifiedChinese)

        let expectation = XCTestExpectation(description: "web3 loaded")
        let web3 = Web3Swift()
        web3.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if web3.isLoaded {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 10)

        //Must change this back to system, otherwise other tests will break either immediately or the next run
        Config.setLocale(AppLocale.system)
    }
}
