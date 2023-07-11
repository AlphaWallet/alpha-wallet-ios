//
//  DomainNameRecordsStorage.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 06.06.2022.
//

import Foundation
import AlphaWalletCore
import Combine
import AlphaWalletENS

public protocol DomainNameRecordsStorage: AnyObject {
    var allRecords: [DomainNameRecord] { get }

    func record(for key: DomainNameLookupKey, expirationTime: TimeInterval) -> DomainNameRecord?
    func addOrUpdate(record: DomainNameRecord)
    func removeRecord(for key: DomainNameLookupKey)
}

extension DomainNameLookupKey {
    init?(object: EnsRecordObject) {
        let components = object.uid.components(separatedBy: "-")
        guard let nameOrAddress = components[safe: 0] else { return nil }
        guard let chainId = components[safe: 1].flatMap({ Int($0) }) else { return nil }

        if let record = components[safe: 2].flatMap { EnsTextRecordKey(rawValue: $0) } {
            self.init(nameOrAddress: nameOrAddress, server: RPCServer(chainID: chainId), record: record)
        } else {
            self.init(nameOrAddress: nameOrAddress, server: RPCServer(chainID: chainId))
        }
    }
}

extension RealmStore: DomainNameRecordsStorage {

    public var allRecords: [DomainNameRecord] {
        var records: [DomainNameRecord] = []
        performSync { realm in
            records = realm.objects(EnsRecordObject.self).compactMap { DomainNameRecord(recordObject: $0) }
        }
        return records
    }

    public func record(for key: DomainNameLookupKey, expirationTime: TimeInterval) -> DomainNameRecord? {
        var record: DomainNameRecord?
        let expirationDate = NSDate(timeInterval: expirationTime, since: Date())
        let predicate = NSPredicate(format: "uid = %@ AND creatingDate > %@", key.description, expirationDate)

        performSync { realm in
            record = realm.objects(EnsRecordObject.self)
                .filter(predicate)
                .first
                .flatMap { DomainNameRecord(recordObject: $0) }
        }

        return record
    }

    public func addOrUpdate(record: DomainNameRecord) {
        performSync { realm in
            try? realm.safeWrite {
                let object = EnsRecordObject(record: record)

                realm.add(object, update: .all)
            }
        }
    }

    public func removeRecord(for key: DomainNameLookupKey) {
        let predicate = NSPredicate(format: "uid == '\(key.description)'")
        performSync { realm in
            try? realm.safeWrite {
                let objects = realm.objects(EnsRecordObject.self).filter(predicate)
                realm.delete(objects)
            }
        }
    }
}

extension DomainNameRecord {
    init?(recordObject: EnsRecordObject) {
        guard let key = DomainNameLookupKey(object: recordObject) else { return nil }
        let date = recordObject.creatingDate as Date
        if let addressString = recordObject.addressRawValue, let address = AlphaWallet.Address(string: addressString) {
            self.init(key: key, value: .address(address), date: date)
        } else if let record = recordObject.recordRawValue {
            self.init(key: key, value: .record(record), date: date)
        } else if let domainName = recordObject.ensRawValue {
            self.init(key: key, value: .domainName(domainName), date: date)
        } else {
            return nil
        }
    }
}
