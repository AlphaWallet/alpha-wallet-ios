//
//  ScheduledToDoTest.swift
//  AlphaWalletTests
//
//  Created by Jerome Chan on 6/4/23.
//
/// This class abuses the test suite to generate reminders when TODOs are due

import XCTest

final class ScheduledToDoTest: XCTestCase {

    func testReminderToRemoveSpamTokenIconFilesFromIconAssetsRepo() throws {
        let expirationDate = ISO8601DateFormatter().date(from: "2023-08-06T00:00:00Z")! // 6th July 2023
        XCTAssertFalse(dueDateElapsed(expirationDate: expirationDate), "TODO:- Spam Token Icon Removal task: https://github.com/AlphaWallet/iconassets/issues/30")
    }

    func testReminderToCheckKlaytnBlockchainExplorerAPI() throws {
        let expirationDate = ISO8601DateFormatter().date(from: "2023-08-11T00:00:00Z")!
        XCTAssertFalse(dueDateElapsed(expirationDate: expirationDate), "TODO:- Check Klaytn blockchain explorer API again. `services-monitor` was disabled because they were always down https://github.com/AlphaWallet/services-monitor/pull/49")
    }

    private func dueDateElapsed(expirationDate: Date) -> Bool {
        let currentDate = Date()
        return expirationDate.isEarlierThan(date: currentDate)
    }

}
