//
//  EnsRecord.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 06.06.2022.
//

import Foundation
import AlphaWalletAddress

public typealias EnsName = String
public typealias EnsTextRecord = String

public struct EnsRecord {
    public let key: EnsLookupKey
    public let value: EnsRecord.Value
    public let date: Date

    public init(key: EnsLookupKey, value: EnsRecord.Value, date: Date) {
        self.key = key
        self.value = value
        self.date = date
    }
}

extension EnsRecord {
    public init(key: EnsLookupKey, value: EnsRecord.Value) {
        self.init(key: key, value: value, date: Date())
    }
}

extension EnsRecord {
    public enum Value {
        case record(EnsTextRecord)
        case ens(EnsName)
        case address(AlphaWallet.Address)
    }
}

extension EnsRecord.Value: Equatable {
    public static func == (lhs: EnsRecord.Value, rhs: EnsRecord.Value) -> Bool {
        switch (lhs, rhs) {
        case (.record(let r1), .record(let r2)):
            return r1 == r2
        case (.ens(let e1), .ens(let e2)):
            return e1 == e2
        case (.address(let a1), .address(let a2)):
            return a1.sameContract(as: a2)
        default:
            return false
        }
    }
}

extension EnsRecord: Equatable {
    public static func == (lhs: EnsRecord, rhs: EnsRecord) -> Bool {
        lhs.key.description == rhs.key.description && lhs.date == rhs.date && lhs.value == rhs.value
    }
}
