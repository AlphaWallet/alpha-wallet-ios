// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import RealmSwift

extension FakeTransactionsStorage {
    var count: Int {
        transactionCount(forServer: .main)
    }
}

class TransactionsStorageTests: XCTestCase {

    func testInit() {
        let storage = FakeTransactionsStorage()

        XCTAssertNotNil(storage)
        XCTAssertEqual(0, storage.count)
    }

    func testAddItem() {
        let storage = FakeTransactionsStorage()
        let item: Transaction = .make()

        storage.add(transactions: [item])

        XCTAssertEqual(1, storage.count)
    }

    func testAddItems() {
        let storage = FakeTransactionsStorage()

        storage.add(transactions: [
            .make(id: "0x1"),
            .make(id: "0x2")
        ])

        XCTAssertEqual(2, storage.count)
    }

    func testAddItemsDuplicate() {
        let storage = FakeTransactionsStorage()

        storage.add(transactions: [
            .make(id: "0x1"),
            .make(id: "0x1"),
            .make(id: "0x2")
        ])

        XCTAssertEqual(2, storage.count)
    }

    func testDelete() {
        let storage = FakeTransactionsStorage()
        let one: Transaction = .make(id: "0x1")
        let two: Transaction = .make(id: "0x2")

        storage.add(transactions: [
            one,
            two,
        ])

        XCTAssertEqual(2, storage.count)

        storage.delete([one])

        XCTAssertEqual(1, storage.count)

        XCTAssertEqual(two.primaryKey, storage.transactions(forServer: .main).first!.primaryKey)
    }

    func testDeleteAll() {
        let storage = FakeTransactionsStorage()

        storage.add(transactions: [
            .make(id: "0x1"),
            .make(id: "0x2")
        ])

        XCTAssertEqual(2, storage.count)

        storage.deleteAllForTestsOnly()

        XCTAssertEqual(0, storage.count)
    }
}
