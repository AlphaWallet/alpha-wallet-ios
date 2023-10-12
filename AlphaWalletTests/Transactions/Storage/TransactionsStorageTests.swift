// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class TransactionsStorageTests: XCTestCase {

    func testInit() async {
        let storage = FakeTransactionsStorage()

        XCTAssertNotNil(storage)
        let transactionCount = await storage.transactionCount(forServer: .main)
        XCTAssertEqual(0, transactionCount)
    }

    func testAddItem() async {
        let storage = FakeTransactionsStorage()
        let item: Transaction = .make()

        await storage.add(transactions: [item])
        let transactionCount = await storage.transactionCount(forServer: .main)
        XCTAssertEqual(1, transactionCount)
    }

    func testAddItems() async {
        let storage = FakeTransactionsStorage()

        await storage.add(transactions: [
            .make(id: "0x1"),
            .make(id: "0x2")
        ])

        let transactionCount = await storage.transactionCount(forServer: .main)
        XCTAssertEqual(2, transactionCount)
    }

    func testAddItemsDuplicate() async {
        let storage = FakeTransactionsStorage()

        await storage.add(transactions: [
            .make(id: "0x1"),
            .make(id: "0x1"),
            .make(id: "0x2")
        ])

        let transactionCount = await storage.transactionCount(forServer: .main)
        XCTAssertEqual(2, transactionCount)
    }

    func testDelete() async {
        let storage = FakeTransactionsStorage()
        let one: Transaction = .make(id: "0x1")
        let two: Transaction = .make(id: "0x2")

        await storage.add(transactions: [
            one,
            two,
        ])

        let transactionCount = await storage.transactionCount(forServer: .main)
        XCTAssertEqual(2, transactionCount)

        await storage.delete(transactions: [one]).value

        let transactionCount2 = await storage.transactionCount(forServer: .main)
        XCTAssertEqual(1, transactionCount2)

        let transaction = await storage.transactions(forServer: .main).first
        XCTAssertEqual(two, transaction)
    }

    func testDeleteAll() async {
        let storage = FakeTransactionsStorage()

        await storage.add(transactions: [
            .make(id: "0x1"),
            .make(id: "0x2")
        ])

        let transactionCount = await storage.transactionCount(forServer: .main)
        XCTAssertEqual(2, transactionCount)

        await storage.deleteAllForTestsOnly().value

        let transactionCount2 = await storage.transactionCount(forServer: .main)
        XCTAssertEqual(0, transactionCount2)
    }
}
