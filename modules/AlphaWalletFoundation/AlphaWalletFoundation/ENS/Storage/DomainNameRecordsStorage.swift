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
    var allRecords: [DomainNameRecord] { get async }

    func record(for key: DomainNameLookupKey, expirationTime: TimeInterval) async -> DomainNameRecord?
    func addOrUpdate(record: DomainNameRecord) async
    func removeRecord(for key: DomainNameLookupKey) async
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
        get async {
            var records: [DomainNameRecord] = []
            await perform { realm in
                records = realm.objects(EnsRecordObject.self).compactMap { DomainNameRecord(recordObject: $0) }
            }
            return records
        }
    }

    public func record(for key: DomainNameLookupKey, expirationTime: TimeInterval) async -> DomainNameRecord? {
        var record: DomainNameRecord?
        let expirationDate = NSDate(timeInterval: expirationTime, since: Date())
        let predicate = NSPredicate(format: "uid = %@ AND creatingDate > %@", key.description, expirationDate)

        await perform { realm in
            record = realm.objects(EnsRecordObject.self)
                .filter(predicate)
                .first
                .flatMap { DomainNameRecord(recordObject: $0) }
        }

        return record
    }

    public func addOrUpdate(record: DomainNameRecord) async {
        await perform { realm in
            try? realm.safeWrite {
                let object = EnsRecordObject(record: record)

                realm.add(object, update: .all)
            }
        }
    }

    public func removeRecord(for key: DomainNameLookupKey) async {
        let predicate = NSPredicate(format: "uid == '\(key.description)'")
        await perform { realm in
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
