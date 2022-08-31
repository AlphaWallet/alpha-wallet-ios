//
//  EnsRecordsStorage.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 06.06.2022.
//

import Foundation
import AlphaWalletCore
import Combine
import AlphaWalletENS

public protocol EnsRecordsStorage: AnyObject {
    var allRecords: [EnsRecord] { get }

    func record(for key: EnsLookupKey, expirationTime: TimeInterval) -> EnsRecord?
    func addOrUpdate(record: EnsRecord)
    func removeRecord(for key: EnsLookupKey)
}

extension EnsLookupKey {
    init?(object: EnsRecordObject) {
        let components = object.uid.components(separatedBy: "-")
        guard let nameOrAddress = components[safe: 0] else { return nil }
        guard let chainId = components[safe: 1].flatMap({ Int($0) }) else { return nil }

        self.server = RPCServer(chainID: chainId)
        self.record = components[safe: 2].flatMap { EnsTextRecordKey(rawValue: $0) }
        self.nameOrAddress = nameOrAddress
    }
}

extension RealmStore: EnsRecordsStorage {

    public var allRecords: [EnsRecord] {
        var records: [EnsRecord] = []
        performSync { realm in
            records = realm.objects(EnsRecordObject.self).compactMap { EnsRecord(recordObject: $0) }
        }
        return records
    }

    public func record(for key: EnsLookupKey, expirationTime: TimeInterval) -> EnsRecord? {
        var record: EnsRecord?
        let expirationDate = NSDate(timeInterval: expirationTime, since: Date())
        let predicate = NSPredicate(format: "uid = %@ AND creatingDate > %@", key.description, expirationDate)

        performSync { realm in
            record = realm.objects(EnsRecordObject.self)
                .filter(predicate)
                .first
                .flatMap { EnsRecord(recordObject: $0) }
        }

        return record
    }

    public func addOrUpdate(record: EnsRecord) {
        performSync { realm in
            try? realm.safeWrite {
                let object = EnsRecordObject(record: record)

                realm.add(object, update: .all)
            }
        }
    }

    public func removeRecord(for key: EnsLookupKey) {
        let predicate = NSPredicate(format: "uid == '\(key.description)'")
        performSync { realm in
            try? realm.safeWrite {
                let objects = realm.objects(EnsRecordObject.self).filter(predicate)
                realm.delete(objects)
            }
        }
    }
}

extension EnsRecord {
    init?(recordObject: EnsRecordObject) {
        guard let key = EnsLookupKey(object: recordObject) else { return nil }
        self.key = key
        self.date = recordObject.creatingDate as Date
        if let addressString = recordObject.addressRawValue, let address = AlphaWallet.Address(string: addressString) {
            self.value = .address(address)
        } else if let record = recordObject.recordRawValue {
            self.value = .record(record)
        } else if let ens = recordObject.ensRawValue {
            self.value = .ens(ens)
        } else {
            return nil
        }
    }
}
