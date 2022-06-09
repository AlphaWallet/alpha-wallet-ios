// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class TransactionsStorageTests: XCTestCase {

    func testInit() {
        let storage = FakeTransactionsStorage()

        XCTAssertNotNil(storage)
        XCTAssertEqual(0, storage.transactionCount(forServer: .main))
    }

    func testAddItem() {
        let storage = FakeTransactionsStorage()
        let item: TransactionInstance = .make()

        storage.add(transactions: [item])

        XCTAssertEqual(1, storage.transactionCount(forServer: .main))
    }

    func testAddItems() {
        let storage = FakeTransactionsStorage()

        storage.add(transactions: [
            .make(id: "0x1"),
            .make(id: "0x2")
        ])

        XCTAssertEqual(2, storage.transactionCount(forServer: .main))
    }

    func testAddItemsDuplicate() {
        let storage = FakeTransactionsStorage()

        storage.add(transactions: [
            .make(id: "0x1"),
            .make(id: "0x1"),
            .make(id: "0x2")
        ])

        XCTAssertEqual(2, storage.transactionCount(forServer: .main))
    }

    func testDelete() {
        let storage = FakeTransactionsStorage()
        let one: TransactionInstance = .make(id: "0x1")
        let two: TransactionInstance = .make(id: "0x2")

        storage.add(transactions: [
            one,
            two,
        ])

        XCTAssertEqual(2, storage.transactionCount(forServer: .main))

        storage.delete([one])

        XCTAssertEqual(1, storage.transactionCount(forServer: .main))

        XCTAssertEqual(two, storage.transactions(forServer: .main).first)
    }

    func testDeleteAll() {
        let storage = FakeTransactionsStorage()

        storage.add(transactions: [
            .make(id: "0x1"),
            .make(id: "0x2")
        ])

        XCTAssertEqual(2, storage.transactionCount(forServer: .main))

        storage.deleteAllForTestsOnly()

        XCTAssertEqual(0, storage.transactionCount(forServer: .main))
    }
}
