// Copyright SIX DAY LLC. All rights reserved.

@testable import AlphaWallet
import AlphaWalletFoundation
import XCTest

class AppTrackerTests: XCTestCase {
    func testLaunchCountForCurrentBuild() {
        let tracker = AppTracker(defaults: .test)

        XCTAssertEqual(0, tracker.launchCountForCurrentBuild)

        tracker.start()

        XCTAssertEqual(1, tracker.launchCountForCurrentBuild)

        tracker.start()

        XCTAssertEqual(2, tracker.launchCountForCurrentBuild)
    }
}
