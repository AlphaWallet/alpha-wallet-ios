// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public enum ImportType {
    case keystore(string: String, password: String)
    case privateKey(privateKey: Data)
    case mnemonic(words: [String], password: String)
    case watch(address: AlphaWallet.Address)
    case new(seedPhraseCount: HDWallet.SeedPhraseCount, passphrase: String)

    public static var newWallet: ImportType {
        return .new(seedPhraseCount: .word12, passphrase: "")
    }
}
