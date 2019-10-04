// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit

enum AssetInternalValue: Codable {
    case address(AlphaWallet.Address)
    case string(String)
    case bytes(Data)
    case int(BigInt)
    case uint(BigUInt)
    case generalisedTime(GeneralisedTime)
    case bool(Bool)
    case subscribable(Subscribable<AssetInternalValue>)
    case openSeaNonFungibleTraits([OpenSeaNonFungibleTrait])

    var resolvedValue: AssetInternalValue? {
        switch self {
        case .address, .string, .int, .uint, .generalisedTime, .bool, .bytes:
            return self
        case .subscribable(let subscribable):
            return subscribable.value
        case .openSeaNonFungibleTraits:
            return nil
        }
    }

    var addressValue: AlphaWallet.Address? {
        guard case .address(let value) = self else { return nil }
        return value
    }
    var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }
    var intValue: BigInt? {
        guard case .int(let value) = self else { return nil }
        return value
    }
    var uintValue: BigUInt? {
        guard case .uint(let value) = self else { return nil }
        return value
    }
    var generalisedTimeValue: GeneralisedTime? {
        guard case .generalisedTime(let value) = self else { return nil }
        return value
    }
    var boolValue: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }
    var subscribableValue: Subscribable<AssetInternalValue>? {
        guard case .subscribable(let value) = self else { return nil }
        return value
    }
    var openSeaNonFungibleTraitsValue: [OpenSeaNonFungibleTrait]? {
        guard case .openSeaNonFungibleTraits(let value) = self else { return nil }
        return value
    }

    var bytesValue: Data? {
        guard case .bytes(let value) = self else { return nil }
        return value
    }
    var isSubscribableValue: Bool {
        return subscribableValue != nil
    }

    enum Key: CodingKey {
        case address
        case string
        case bytes
        case int
        case uint
        case generalisedTime
        case bool
    }

    enum AssetIntervalValueCodingError: Error {
        case cannotEncode(AssetInternalValue)
        case cannotDecode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)

        if let address = try? container.decode(AlphaWallet.Address.self, forKey: .address) {
            self = .address(address)
            return
        }
        if let string = try? container.decode(String.self, forKey: .string) {
            self = .string(string)
            return
        }
        if let bytes = try? container.decode(Data.self, forKey: .bytes) {
            self = .bytes(bytes)
            return
        }
        if let int = try? container.decode(BigInt.self, forKey: .int) {
            self = .int(int)
            return
        }
        if let uint = try? container.decode(BigUInt.self, forKey: .uint) {
            self = .uint(uint)
            return
        }
        if let generalisedTime = try? container.decode(GeneralisedTime.self, forKey: .generalisedTime) {
            self = .generalisedTime(generalisedTime)
            return
        }
        if let bool = try? container.decode(Bool.self, forKey: .bool) {
            self = .bool(bool)
            return
        }
        throw AssetIntervalValueCodingError.cannotDecode
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case .address(let value):
            try container.encode(value, forKey: .address)
        case .string(let value):
            try container.encode(value, forKey: .string)
        case .int(let value):
            try container.encode(value, forKey: .int)
        case .uint(let value):
            try container.encode(value, forKey: .uint)
        case .generalisedTime(let value):
            try container.encode(value, forKey: .generalisedTime)
        case .bool(let value):
            try container.encode(value, forKey: .bool)
        case .subscribable, .openSeaNonFungibleTraits:
            throw AssetIntervalValueCodingError.cannotEncode(self)
        case .bytes(let value):
            try container.encode(value, forKey: .bytes)
        }
    }
}

extension Array where Element == Subscribable<AssetInternalValue> {
    func createPromiseForSubscribeOnce() -> Promise<Void> {
        guard !isEmpty else { return .value(Void()) }
        return Promise { seal in
            var count = 0
            for each in self {
                each.subscribeOnce { _ in
                    count += 1
                    guard count == self.count else { return }
                    seal.fulfill(Void())
                }
            }
        }
    }
}
