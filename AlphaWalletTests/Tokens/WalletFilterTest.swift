// Copyright © 2022 Stormbird PTE. LTD.

@testable import AlphaWallet
import AlphaWalletFoundation
import XCTest

class WalletFilterTest: XCTestCase {
    func testWalletSubTabsIndices() {
        let selectionIndices: [UInt] = WalletFilter.orderedTabs.map(\.selectionIndex).compactMap { $0 }
        XCTAssertEqual(selectionIndices.count, WalletFilter.orderedTabs.count)
    }
}
