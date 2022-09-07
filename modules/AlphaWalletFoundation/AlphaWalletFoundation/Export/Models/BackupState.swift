// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import BigInt

public enum WalletSecurityLevel {
    case notBackedUp
    case backedUpButSecurityIsNotElevated
    case backedUpWithElevatedSecurity
}

public struct WalletsBackupState: Codable {
    public enum Prompt {
        case newWallet
        case receivedNativeCryptoCurrency(BigInt)
        case intervalPassed
        case nativeCryptoCurrencyDollarValueExceededThreshold
    }

    public struct BackupState: Codable {
        public var shownNativeCryptoCurrencyReceivedPrompt: Bool = false
        public var timeToShowIntervalPassedPrompt: Date?
        public var shownNativeCryptoCurrencyDollarValueExceedThresholdPrompt: Bool = false
        public var lastBackedUpTime: Date?
        public var isImported: Bool

        public init(shownNativeCryptoCurrencyReceivedPrompt: Bool = false, timeToShowIntervalPassedPrompt: Date?, shownNativeCryptoCurrencyDollarValueExceedThresholdPrompt: Bool = false, lastBackedUpTime: Date?, isImported: Bool) {
            self.shownNativeCryptoCurrencyReceivedPrompt = shownNativeCryptoCurrencyReceivedPrompt
            self.timeToShowIntervalPassedPrompt = timeToShowIntervalPassedPrompt
            self.shownNativeCryptoCurrencyDollarValueExceedThresholdPrompt = shownNativeCryptoCurrencyDollarValueExceedThresholdPrompt
            self.lastBackedUpTime = lastBackedUpTime
            self.isImported = isImported
        }
    }

    public var prompt = [AlphaWallet.Address: Prompt]()
    public var backupState = [AlphaWallet.Address: BackupState]()
    
    public init(prompt: [AlphaWallet.Address: Prompt] = [:], backupState: [AlphaWallet.Address: BackupState] = [:]) {
        self.prompt = prompt
        self.backupState = backupState
    }
    
    public func writeTo(url: URL) {
        let encoder = JSONEncoder()
        let data = try! encoder.encode(self)
        try? data.write(to: url)
    }

    public static func load(fromUrl url: URL) -> WalletsBackupState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WalletsBackupState.self, from: data)
    }
}

extension WalletsBackupState.Prompt: Codable {
    enum Key: CodingKey {
        case rawValue
        case associatedValue
    }

    enum CodingError: Error {
        case unknownValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let rawValue = try container.decode(Int.self, forKey: .rawValue)
        switch rawValue {
        case 0:
            self = .newWallet
        case 1:
            let nativeCryptoCurrency = try container.decode(BigInt.self, forKey: .associatedValue)
            self = .receivedNativeCryptoCurrency(nativeCryptoCurrency)
        case 2:
            self = .intervalPassed
        case 3:
            self = .nativeCryptoCurrencyDollarValueExceededThreshold
        default:
            throw CodingError.unknownValue
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case .newWallet:
            try container.encode(0, forKey: .rawValue)
        case .receivedNativeCryptoCurrency(let nativeCryptoCurrency):
            try container.encode(1, forKey: .rawValue)
            try container.encode(nativeCryptoCurrency, forKey: .associatedValue)
        case .intervalPassed:
            try container.encode(2, forKey: .rawValue)
        case .nativeCryptoCurrencyDollarValueExceededThreshold:
            try container.encode(3, forKey: .rawValue)
        }
    }
}
