//
//  EnsRecordsStorageTests.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 09.06.2022.
//

import XCTest
import Foundation
@testable import AlphaWallet
import AlphaWalletENS

class EnsRecordsStorageTests: XCTestCase {
    func testIsStorageEmpty() throws {
        let storage = FakeEnsRecordsStorage()
        XCTAssertEqual(storage.allRecords, [], "Storage is empty")
    }

    func testAddRecord() {
        let storage = FakeEnsRecordsStorage()
        XCTAssertEqual(storage.allRecords, [], "Storage is empty")
        let key: DomainNameLookupKey = .init(nameOrAddress: "key", server: .main)
        let r1 = DomainNameRecord(key: key, value: .domainName("hello alpha wallet"))
        storage.addOrUpdate(record: r1)

        XCTAssertEqual(storage.allRecords.count, 1)
    }

    func testUpdateRecord() {
        let storage = FakeEnsRecordsStorage()
        XCTAssertEqual(storage.allRecords, [], "Storage is empty")

        let key: DomainNameLookupKey = .init(nameOrAddress: "key", server: .main)
        let r1 = DomainNameRecord(key: key, value: .domainName("hello alpha wallet"))
        storage.addOrUpdate(record: r1)

        let r1_copy = storage.record(for: key, expirationTime: -120)
        XCTAssertEqual(r1, r1_copy)

        let r10 = DomainNameRecord(key: key, value: .record("image"))
        storage.addOrUpdate(record: r10)

        let r10_copy = storage.record(for: key, expirationTime: -120)
        XCTAssertEqual(r10_copy?.value, .record("image"))
        XCTAssertNotEqual(r1_copy, r10_copy)
    }

    func testFetchExpiredRecord() {
        let storage = FakeEnsRecordsStorage()

        let key: DomainNameLookupKey = .init(nameOrAddress: "key", server: .main)
        let r1 = DomainNameRecord(key: key, value: .domainName("hello alpha wallet"))
        storage.addOrUpdate(record: r1)

        let r1_copy = storage.record(for: key, expirationTime: -120)
        XCTAssertNotNil(r1_copy)
        XCTAssertEqual(r1, r1_copy, "Copy and initial value are queal")

        let dateThatExpired = Date(timeIntervalSinceNow: -600)
        let r10 = DomainNameRecord(key: key, value: .domainName("hello alpha wallet"), date: dateThatExpired)
        storage.addOrUpdate(record: r10)

        let r10_copy = storage.record(for: key, expirationTime: -120)
        XCTAssertNil(r10_copy, "Updated value has expired")
        XCTAssertEqual(storage.allRecords.count, 1, "Storage contains single value")

        storage.removeRecord(for: key)
    }

}
