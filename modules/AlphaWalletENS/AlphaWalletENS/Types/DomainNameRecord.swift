//
//  DomainNameRecord.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 06.06.2022.
//

import Foundation
import AlphaWalletAddress
import AlphaWalletENS

public typealias DomainName = String
public typealias DomainNameTextRecord = String

public struct DomainNameRecord {
    public let key: DomainNameLookupKey
    public let value: DomainNameRecord.Value
    public let date: Date

    public init(key: DomainNameLookupKey, value: DomainNameRecord.Value, date: Date) {
        self.key = key
        self.value = value
        self.date = date
    }
}

extension DomainNameRecord {
    public init(key: DomainNameLookupKey, value: DomainNameRecord.Value) {
        self.init(key: key, value: value, date: Date())
    }
}

extension DomainNameRecord {
    public enum Value {
        case record(DomainNameTextRecord)
        case domainName(DomainName)
        case address(AlphaWallet.Address)
    }
}

extension DomainNameRecord.Value: Equatable {
    public static func == (lhs: DomainNameRecord.Value, rhs: DomainNameRecord.Value) -> Bool {
        switch (lhs, rhs) {
        case (.record(let r1), .record(let r2)):
            return r1 == r2
        case (.domainName(let e1), .domainName(let e2)):
            return e1 == e2
        case (.address(let a1), .address(let a2)):
            return a1 == a2
        default:
            return false
        }
    }
}

extension DomainNameRecord: Equatable {
    public static func == (lhs: DomainNameRecord, rhs: DomainNameRecord) -> Bool {
        lhs.key.description == rhs.key.description && lhs.date == rhs.date && lhs.value == rhs.value
    }
}
