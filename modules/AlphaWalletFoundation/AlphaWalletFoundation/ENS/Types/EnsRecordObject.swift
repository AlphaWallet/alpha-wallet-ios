//
//  EnsRecordObject.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.06.2022.
//

import Foundation
import AlphaWalletENS
import RealmSwift

//Domain name rather than ENS-specific. So includes UnstoppableDomains too. Renaming the type would require a Realm migration
class EnsRecordObject: Object {
    @objc dynamic var uid: String = ""
    @objc dynamic var recordRawValue: String?
    @objc dynamic var ensRawValue: String?
    @objc dynamic var addressRawValue: String?
    @objc dynamic var creatingDate = NSDate()

    convenience init(record: DomainNameRecord) {
        self.init()
        self.uid = record.key.description
        self.creatingDate = record.date as NSDate

        switch record.value {
        case .address(let address):
            self.addressRawValue = address.eip55String
        case .domainName(let ens):
            self.ensRawValue = ens
        case .record(let record):
            self.recordRawValue = record
        }
    }

    override static func primaryKey() -> String? {
        return "uid"
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? EnsRecordObject else { return false }
        //NOTE: to improve perfomance seems like we can use check for primary key instead of checking contracts
        return object.uid == uid
    }
}
