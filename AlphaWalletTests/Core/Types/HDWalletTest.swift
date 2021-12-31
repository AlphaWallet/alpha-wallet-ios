// Copyright © 2019 Stormbird PTE. LTD.

import XCTest
@testable import AlphaWallet
import WalletCore

class HDWalletTest: XCTestCase {
    private func _testComputeSeedFromEnglishMnemonic(seedPhraseCount: HDWallet.SeedPhraseCount) {
        let emptyPassphrase = ""
        for _ in 1...1000 {
            let wallet1 = HDWallet(strength: seedPhraseCount.strength, passphrase: emptyPassphrase)!
            let seed = HDWallet.computeSeedWithChecksum(fromSeedPhrase: wallet1.mnemonic)
            let wallet2 = HDWallet(seed: seed, passphrase: emptyPassphrase)!
            XCTAssertEqual(wallet1.mnemonic, wallet2.mnemonic)
        }
    }

    func testComputeSeedFromEnglish12WordMnemonic() {
        let seedPhraseCount: HDWallet.SeedPhraseCount = .word12
        _testComputeSeedFromEnglishMnemonic(seedPhraseCount: seedPhraseCount)
    }

    func testComputeSeedFromEnglish24WordMnemonic() {
        let seedPhraseCount: HDWallet.SeedPhraseCount = .word24
        _testComputeSeedFromEnglishMnemonic(seedPhraseCount: seedPhraseCount)
    }

    func testComputeSeedFromSpecificEnglish12WordMnemonic() {
        let emptyPassphrase = ""
        //This seed phrase is known to generate the wrong seed phrase when computed from its seed if we do it wrongly, as: spoon spy hungry put siren harbor echo trumpet olympic ordinary alert orient
        let seedPhrase = "artwork essay plunge priority hold repair lounge write situate clap call border"
        let seed = HDWallet.computeSeedWithChecksum(fromSeedPhrase: seedPhrase)
        let wallet = HDWallet(seed: seed, passphrase: emptyPassphrase)!
        XCTAssertEqual(seedPhrase, wallet.mnemonic)
    }

    func testComputeSeedFromSpecificEnglish24WordMnemonic() {
        let emptyPassphrase = ""
        let seedPhrase = "lawsuit rib market click repair require used frog universe label shoot message dad range bonus guitar table long bronze honey mountain plunge virus lunch"
        let seed = HDWallet.computeSeedWithChecksum(fromSeedPhrase: seedPhrase)
        let wallet = HDWallet(seed: seed, passphrase: emptyPassphrase)!
        XCTAssertEqual(seedPhrase, wallet.mnemonic)
    }

    func testLeftPadStringWithZero() {
        XCTAssertEqual(HDWallet.leftPadStringWithZero("abc", to: 5), "00abc")
        XCTAssertEqual(HDWallet.leftPadStringWithZero("abc", to: 3), "abc")
        XCTAssertEqual(HDWallet.leftPadStringWithZero("abc", to: 2), "abc")
        XCTAssertEqual(HDWallet.leftPadStringWithZero("abc", to: 0), "abc")
        XCTAssertEqual(HDWallet.leftPadStringWithZero("abc", to: 6), "000abc")
        XCTAssertEqual(HDWallet.leftPadStringWithZero("", to: 0), "")
        XCTAssertEqual(HDWallet.leftPadStringWithZero("", to: 1), "0")
        XCTAssertEqual(HDWallet.leftPadStringWithZero("", to: 2), "00")
    }
}