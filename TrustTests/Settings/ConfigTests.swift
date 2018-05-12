// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import Trust

class ConfigTests: XCTestCase {
        
    func testChainIDDefault() {
        var config: Config = .make()

        XCTAssertEqual(1, config.chainID)
        XCTAssertEqual(.main, config.server)
    }

    func testChangeChainID() {
        var config: Config = .make()

        XCTAssertEqual(1, config.chainID)

        config.chainID = 42

        XCTAssertEqual(42, config.chainID)
        XCTAssertEqual(.kovan, config.server)
    }

    func testTestDefaultisCryptoPrimaryCurrency() {
        var config: Config = .make()

        XCTAssertEqual(false, config.isCryptoPrimaryCurrency)
    }

    func testSwitchLocale() {
        var config: Config = .make()

        config.locale = AppLocale.english.id
        let vc1 = TokensViewController(
                session: .make(),
                account: .make(),
                dataStore: FakeTokensDataStore()
        )
        XCTAssertEqual(vc1.title, "Wallet")

        config.locale = AppLocale.simplifiedChinese.id
        let vc2 = TokensViewController(
                session: .make(),
                account: .make(),
                dataStore: FakeTokensDataStore()
        )
        XCTAssertEqual(vc2.title, "我的钱包")

        //Must change this back to system, otherwise other tests will break either immediately or the next run
        config.locale = AppLocale.system.id
    }
}

