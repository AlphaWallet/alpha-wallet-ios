// Copyright © 2022 Stormbird PTE. LTD.

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class WalletFilterTest: XCTestCase {
    func testWalletSubTabsIndices() {
        let selectionIndices: [UInt] = WalletFilter.orderedTabs.map(\.selectionIndex).compactMap { $0 }
        XCTAssertEqual(selectionIndices.count, WalletFilter.orderedTabs.count)
    }
}
