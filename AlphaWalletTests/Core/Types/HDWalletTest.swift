// Copyright © 2019 Stormbird PTE. LTD.

import XCTest
@testable import AlphaWallet
import WalletCore

class HDWalletTest: XCTestCase {
    func testComputeSeedFromEnglishMnemonic() {
        let emptyPassphrase = ""
        for _ in 1...100 {
            let wallet1 = HDWallet(strength: 128, passphrase: emptyPassphrase)
            let seed = HDWallet.computeSeedWithChecksum(fromSeedPhrase: wallet1.mnemonic)
            let wallet2 = HDWallet(seed: seed, passphrase: emptyPassphrase)
            XCTAssertEqual(wallet1.mnemonic, wallet2.mnemonic)
        }
    }

    func testComputeSeedFromSpecificEnglishMnemonic() {
        let emptyPassphrase = ""
        //This seed phrase is known to generate the wrong seed phrase when computed from its seed if we do it wrongly, as: spoon spy hungry put siren harbor echo trumpet olympic ordinary alert orient
        let seedPhrase = "artwork essay plunge priority hold repair lounge write situate clap call border"
        let seed = HDWallet.computeSeedWithChecksum(fromSeedPhrase: seedPhrase)
        let wallet = HDWallet(seed: seed, passphrase: emptyPassphrase)
        XCTAssertEqual(seedPhrase, wallet.mnemonic)
    }
}
