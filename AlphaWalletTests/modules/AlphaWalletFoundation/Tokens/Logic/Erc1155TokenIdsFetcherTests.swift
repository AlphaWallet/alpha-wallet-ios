// Copyright © 2022 Stormbird PTE. LTD.

import XCTest
@testable import AlphaWalletFoundation

class Erc1155TokenIdsFetcherTests: XCTestCase {
    func testCombinedBlockNumbersProcessed() {
        XCTAssertEqual(Erc1155TokenIdsFetcher.functional.combinedBlockNumbersProcessed(old: [], newEntry: (0, 10)), [0..<11])
        XCTAssertEqual(Erc1155TokenIdsFetcher.functional.combinedBlockNumbersProcessed(old: [0..<2], newEntry: (0, 10)), [0..<11])
        XCTAssertEqual(Erc1155TokenIdsFetcher.functional.combinedBlockNumbersProcessed(old: [0..<2, 4..<6], newEntry: (0, 10)), [0..<11])
        XCTAssertEqual(Erc1155TokenIdsFetcher.functional.combinedBlockNumbersProcessed(old: [0..<2, 4..<6], newEntry: (2, 10)), [0..<11])
        XCTAssertEqual(Erc1155TokenIdsFetcher.functional.combinedBlockNumbersProcessed(old: [0..<2, 4..<6, 9..<10], newEntry: (2, 10)), [0..<11])
        XCTAssertEqual(Erc1155TokenIdsFetcher.functional.combinedBlockNumbersProcessed(old: [0..<2, 4..<6, 9..<10], newEntry: (2, 20)), [0..<21])
        XCTAssertEqual(Erc1155TokenIdsFetcher.functional.combinedBlockNumbersProcessed(old: [1..<2, 4..<6, 9..<10], newEntry: (2, 20)), [1..<21])
        ////Catch up, so new entry is not at the end
        XCTAssertEqual(Erc1155TokenIdsFetcher.functional.combinedBlockNumbersProcessed(old: [1..<2, 6..<8], newEntry: (4, 5)), [1..<2, 4..<8])
    }

    func testMakeBlockRangeToCatchUpForOlderEvents() {
        //Test not done anything yet. Don't bother catching up
        XCTAssert(Erc1155TokenIdsFetcher.functional.makeBlockRangeToCatchUpForOlderEvents(maximumWindow: 2, excludingRanges: []) == nil)

        //Test caught up
        XCTAssert(Erc1155TokenIdsFetcher.functional.makeBlockRangeToCatchUpForOlderEvents(maximumWindow: 2, excludingRanges: [0..<1]) == nil)
        XCTAssert(Erc1155TokenIdsFetcher.functional.makeBlockRangeToCatchUpForOlderEvents(maximumWindow: 2, excludingRanges: [0..<2]) == nil)
        XCTAssert(Erc1155TokenIdsFetcher.functional.makeBlockRangeToCatchUpForOlderEvents(maximumWindow: 2, excludingRanges: [0..<10]) == nil)

        XCTAssert(Erc1155TokenIdsFetcher.functional.makeBlockRangeToCatchUpForOlderEvents(maximumWindow: 2, excludingRanges: [0..<10, 15..<20])! == (13, 14))
        XCTAssert(Erc1155TokenIdsFetcher.functional.makeBlockRangeToCatchUpForOlderEvents(maximumWindow: 2, excludingRanges: [15..<20])! == (13, 14))
        XCTAssert(Erc1155TokenIdsFetcher.functional.makeBlockRangeToCatchUpForOlderEvents(maximumWindow: 5, excludingRanges: [8..<9, 15..<20])! == (10, 14))
        XCTAssert(Erc1155TokenIdsFetcher.functional.makeBlockRangeToCatchUpForOlderEvents(maximumWindow: 5, excludingRanges: [1..<2, 8..<9,  15..<20])! == (10, 14))
        XCTAssert(Erc1155TokenIdsFetcher.functional.makeBlockRangeToCatchUpForOlderEvents(maximumWindow: 1, excludingRanges: [1..<2, 8..<9, 15..<20])! == (14, 14))
        XCTAssert(Erc1155TokenIdsFetcher.functional.makeBlockRangeToCatchUpForOlderEvents(maximumWindow: 6, excludingRanges: [1..<2, 8..<9, 15..<20])! == (9, 14))
        XCTAssert(Erc1155TokenIdsFetcher.functional.makeBlockRangeToCatchUpForOlderEvents(maximumWindow: 15, excludingRanges: [0..<10, 15..<20])! == (10, 14))

        //Test no maximum window size
        XCTAssert(Erc1155TokenIdsFetcher.functional.makeBlockRangeToCatchUpForOlderEvents(maximumWindow: nil, excludingRanges: [0..<10, 15..<20])! == (10, 14))
    }

    func testMakeBlockRangeForEvents() {
        XCTAssert(Erc1155TokenIdsFetcher.functional.makeBlockRangeForEvents(toBlockNumber: 10, maximumWindow: 2, excludingRanges: [0..<2]) == (9, 10))
        XCTAssert(Erc1155TokenIdsFetcher.functional.makeBlockRangeForEvents(toBlockNumber: 10, maximumWindow: 2, excludingRanges: [0..<10]) == (10, 10))
        XCTAssert(Erc1155TokenIdsFetcher.functional.makeBlockRangeForEvents(toBlockNumber: 24, maximumWindow: 2, excludingRanges: [0..<10, 15..<20]) == (23, 24))
        XCTAssert(Erc1155TokenIdsFetcher.functional.makeBlockRangeForEvents(toBlockNumber: 22, maximumWindow: 2, excludingRanges: [0..<10, 15..<20]) == (21, 22))
        XCTAssert(Erc1155TokenIdsFetcher.functional.makeBlockRangeForEvents(toBlockNumber: 21, maximumWindow: 2, excludingRanges: [0..<10, 15..<20]) == (20, 21))
        XCTAssert(Erc1155TokenIdsFetcher.functional.makeBlockRangeForEvents(toBlockNumber: 20, maximumWindow: 2, excludingRanges: [0..<10, 15..<20]) == (20, 20))
        XCTAssert(Erc1155TokenIdsFetcher.functional.makeBlockRangeForEvents(toBlockNumber: 20, maximumWindow: 2, excludingRanges: []) == (19, 20))
        XCTAssert(Erc1155TokenIdsFetcher.functional.makeBlockRangeForEvents(toBlockNumber: 10, maximumWindow: 4, excludingRanges: [0..<5]) == (7, 10))
        XCTAssert(Erc1155TokenIdsFetcher.functional.makeBlockRangeForEvents(toBlockNumber: 10, maximumWindow: 20, excludingRanges: [0..<5]) == (5, 10))

        //Test no maximum window size
        XCTAssert(Erc1155TokenIdsFetcher.functional.makeBlockRangeForEvents(toBlockNumber: 10, maximumWindow: nil, excludingRanges: [0..<2]) == (2, 10))
        XCTAssert(Erc1155TokenIdsFetcher.functional.makeBlockRangeForEvents(toBlockNumber: 10, maximumWindow: nil, excludingRanges: [0..<5]) == (5, 10))
    }
}