// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import BigInt

struct WalletsBackupState: Codable {
    enum Prompt {
        case newWallet
        case receivedNativeCryptoCurrency(BigInt)
        case intervalPassed
        case nativeCryptoCurrencyDollarValueExceededThreshold
    }

    struct BackupState: Codable {
        var shownNativeCryptoCurrencyReceivedPrompt = false
        var timeToShowIntervalPassedPrompt: Date?
        var shownNativeCryptoCurrencyDollarValueExceedThresholdPrompt = false
        var lastBackedUpTime: Date?
        var isImported: Bool
    }

    var prompt = [AlphaWallet.Address: Prompt]()
    var backupState = [AlphaWallet.Address: BackupState]()

    func writeTo(url: URL) {
        let encoder = JSONEncoder()
        let data = try! encoder.encode(self)
        try? data.write(to: url)
    }

    static func load(fromUrl url: URL) -> WalletsBackupState? {
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

    init(from decoder: Decoder) throws {
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

    func encode(to encoder: Encoder) throws {
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
