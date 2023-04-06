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
        let expirationDate = ISO8601DateFormatter().date(from: "2023-05-06T00:00:00Z")! // 6th May 2023
        XCTAssertFalse(dueDateElapsed(expirationDate: expirationDate), "TODO:- Spam Token Icon Removal task: https://github.com/AlphaWallet/iconassets/issues/30")
    }

    private func dueDateElapsed(expirationDate: Date) -> Bool {
        let currentDate = Date()
        return expirationDate.isEarlierThan(date: currentDate)
    }

}
