//
//  TransactionsPaginationStorage.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 09.03.2023.
//

import Foundation

public struct WalletConfig {
    public let defaults: UserDefaults

    public init(address: AlphaWallet.Address) {
        self.defaults = UserDefaults(suiteName: address.eip55String)!
    }

    public func clear() {
        let dictionary = defaults.dictionaryRepresentation()
        dictionary.keys.forEach { defaults.removeObject(forKey: $0) }
    }
}
