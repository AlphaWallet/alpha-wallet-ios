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

let sharedEnsRecordsStorage: EnsRecordsStorage = {
    let storage: EnsRecordsStorage = RealmStore.shared
    return storage
}()

protocol EnsRecordsStorage: AnyObject {
    var recordCount: Int { get }

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

    var recordCount: Int {
        var count: Int = 0
        performSync { realm in
            count = realm.objects(EnsRecordObject.self).count
        }
        return count
    }

    func record(for key: EnsLookupKey, expirationTime: TimeInterval) -> EnsRecord? {
        var record: EnsRecord?
        let expirationDate = NSDate(timeIntervalSinceNow: expirationTime)
        let predicate = NSPredicate(format: "uid = %@ AND creatingDate < %@", key.description, expirationDate)

        performSync { realm in
            record = realm.objects(EnsRecordObject.self)
                .filter(predicate)
                .first
                .flatMap { EnsRecord(recordObject: $0) }
        }

        return record
    }

    func addOrUpdate(record: EnsRecord) {
        performSync { realm in
            try? realm.safeWrite {
                let object = EnsRecordObject(record: record)

                realm.add(object, update: .all)
            }
        }
    }

    func removeRecord(for key: EnsLookupKey) {
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
