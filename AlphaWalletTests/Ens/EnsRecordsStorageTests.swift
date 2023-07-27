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
    func testIsStorageEmpty() async throws {
        let storage = FakeEnsRecordsStorage()
        let records = await storage.allRecords
        XCTAssertEqual(records, [], "Storage is empty")
    }

    func testAddRecord() async {
        let storage = FakeEnsRecordsStorage()
        let records = await storage.allRecords
        XCTAssertEqual(records, [], "Storage is empty")
        let key: DomainNameLookupKey = .init(nameOrAddress: "key", server: .main)
        let r1 = DomainNameRecord(key: key, value: .domainName("hello alpha wallet"))
        await storage.addOrUpdate(record: r1)

        let recordCount = await storage.allRecords.count
        XCTAssertEqual(recordCount, 1)
    }

    func testUpdateRecord() async {
        let storage = FakeEnsRecordsStorage()
        let records = await storage.allRecords
        XCTAssertEqual(records, [], "Storage is empty")

        let key: DomainNameLookupKey = .init(nameOrAddress: "key", server: .main)
        let r1 = DomainNameRecord(key: key, value: .domainName("hello alpha wallet"))
        await storage.addOrUpdate(record: r1)

        let r1_copy = await storage.record(for: key, expirationTime: -120)
        XCTAssertEqual(r1, r1_copy)

        let r10 = DomainNameRecord(key: key, value: .record("image"))
        await storage.addOrUpdate(record: r10)

        let r10_copy = await storage.record(for: key, expirationTime: -120)
        XCTAssertEqual(r10_copy?.value, .record("image"))
        XCTAssertNotEqual(r1_copy, r10_copy)
    }

    func testFetchExpiredRecord() async {
        let storage = FakeEnsRecordsStorage()

        let key: DomainNameLookupKey = .init(nameOrAddress: "key", server: .main)
        let r1 = DomainNameRecord(key: key, value: .domainName("hello alpha wallet"))
        await storage.addOrUpdate(record: r1)

        let r1_copy = await storage.record(for: key, expirationTime: -120)
        XCTAssertNotNil(r1_copy)
        XCTAssertEqual(r1, r1_copy, "Copy and initial value are queal")

        let dateThatExpired = Date(timeIntervalSinceNow: -600)
        let r10 = DomainNameRecord(key: key, value: .domainName("hello alpha wallet"), date: dateThatExpired)
        await storage.addOrUpdate(record: r10)

        let r10_copy = await storage.record(for: key, expirationTime: -120)
        XCTAssertNil(r10_copy, "Updated value has expired")
        let recordCount = await storage.allRecords.count
        XCTAssertEqual(recordCount, 1, "Storage contains single value")

        await storage.removeRecord(for: key)
    }
}
