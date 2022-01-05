// Copyright SIX DAY LLC. All rights reserved.

import XCTest
import LocalAuthentication
@testable import AlphaWallet
import BigInt
import KeychainSwift
import TrustKeystore
import WalletCore

class EtherKeystoreTests: XCTestCase {

    func testInitialization() {
        let keystore = FakeEtherKeystore()

        XCTAssertNotNil(keystore)
        XCTAssertEqual(false, keystore.hasWallets)
    }

    func testCreateWallet() {
        let keystore = FakeEtherKeystore()
        let _ = keystore.createAccount()
        XCTAssertEqual(1, keystore.wallets.count)
    }

    func testEmptyPassword() {
        let keystore = try! LegacyFileBasedKeystore(analyticsCoordinator: FakeAnalyticsService())
        let password = keystore.getPassword(for: .make())
        XCTAssertNil(password)
    }

    func testImport() {
        let keystore = FakeEtherKeystore()
        let expectation = self.expectation(description: "completion block called")
        keystore.importWallet(type: .keystore(string: TestKeyStore.keystore, password: TestKeyStore.password)) { result in
            expectation.fulfill()
            let wallet = try! result.dematerialize()
            XCTAssertEqual("0x5E9c27156a612a2D516C74c7a80af107856F8539", wallet.address.eip55String)
            XCTAssertEqual(1, keystore.wallets.count)
        }
        wait(for: [expectation], timeout: 0.01)
    }

    func testImportDuplicate() {
        let keystore = FakeEtherKeystore()
        var address: AlphaWallet.Address?
        let expectation1 = self.expectation(description: "completion block called")
        let expectation2 = self.expectation(description: "completion block called")
        let expectations = [expectation1, expectation2]
        keystore.importWallet(type: .keystore(string: TestKeyStore.keystore, password: TestKeyStore.password)) { result in
            expectation1.fulfill()
            let wallet = try! result.dematerialize()
            address = wallet.address
        }
        keystore.importWallet(type: .keystore(string: TestKeyStore.keystore, password: TestKeyStore.password)) { result in
            expectation2.fulfill()
            switch result {
            case .success:
                return XCTFail()
            case .failure(let error):
                if case KeystoreError.duplicateAccount = error {
                    XCTAssertEqual("0x5E9c27156a612a2D516C74c7a80af107856F8539", address?.eip55String)
                    XCTAssertEqual(1, keystore.wallets.count)
                } else {
                    XCTFail()
                }
            }
        }
        wait(for: expectations, timeout: 0.01)
    }

    func testImportFailInvalidPassword() {
        let keystore = FakeEtherKeystore()
        keystore.importWallet(type: .keystore(string: TestKeyStore.keystore, password: "invalidPassword")) { result in
            XCTAssertNotNil(result.error)
        }
        XCTAssertEqual(0, keystore.wallets.count)
    }

    func testExportHdWalletToSeedPhrase() {
        let keystore = FakeEtherKeystore()
        let result = keystore.createAccount()
        let account = try! result.dematerialize()
        let expectation = self.expectation(description: "completion block called")
        keystore.exportSeedPhraseOfHdWallet(forAccount: account, context: .init(), reason: .backup) { result in
            expectation.fulfill()
            let seedPhrase = try! result.dematerialize()
            XCTAssertEqual(seedPhrase.split(separator: " ").count, 12)
        }
        wait(for: [expectation], timeout: 0.01)
    }

    func testExportRawPrivateKeyToKeystoreFile() {
        let keystore = FakeEtherKeystore()
        let password = "test"

        XCTAssertEqual(keystore.wallets.count, 0)
        let result = keystore.importWallet(type: .privateKey(privateKey: Data(hexString: TestKeyStore.testPrivateKey)!))
        let wallet = try! result.dematerialize()
        XCTAssertEqual(keystore.wallets.count, 1)

        let expectation = self.expectation(description: "completion block called")
        keystore.exportRawPrivateKeyForNonHdWalletForBackup(forAccount: wallet.address, newPassword: password) { result in
            expectation.fulfill()
            let _ = try! result.dematerialize()
        }
        wait(for: [expectation], timeout: 0.01)
    }

    func testRecentlyUsedAccount() {
        let keystore = FakeEtherKeystore()

        XCTAssertNil(keystore.recentlyUsedWallet)

        let account = try! Wallet(type: .real(keystore.createAccount().dematerialize()))

        keystore.recentlyUsedWallet = account

        XCTAssertEqual(account, keystore.recentlyUsedWallet)
        XCTAssertEqual(account, keystore.currentWallet)

        keystore.recentlyUsedWallet = nil

        XCTAssertNil(keystore.recentlyUsedWallet)
    }

    func testDeleteAccount() {
        let keystore = FakeEtherKeystore()
        let wallet = try! Wallet(type: .real(keystore.createAccount().dematerialize()))

        XCTAssertEqual(1, keystore.wallets.count)

        let result = keystore.delete(wallet: wallet)

        guard case .success = result else { return XCTFail() }

        XCTAssertTrue(keystore.wallets.isEmpty)
    }

    func testConvertPrivateKeyToKeyStore() {
        let passphrase = "MyHardPassword!"
        let keystore = FakeEtherKeystore()
        let result = (try! LegacyFileBasedKeystore(analyticsCoordinator: FakeAnalyticsService())).convertPrivateKeyToKeystoreFile(privateKey: Data(hexString: TestKeyStore.testPrivateKey)!, passphrase: passphrase)
        let dict = try! result.dematerialize()
        keystore.importWallet(type: .keystore(string: dict.jsonString!, password: passphrase)) { result in
            let wallet = try! result.dematerialize()
            XCTAssertEqual(wallet.address.eip55String, "0x95fc7381950Db9d7ab116099c4E84AFD686e3e9C")
            XCTAssertEqual(1, keystore.wallets.count)
        }
    }

    func testSignPersonalMessageWithRawPrivateKey() {
        let keystore = FakeEtherKeystore()
        let expectation = self.expectation(description: "completion block called")

        keystore.importWallet(type: .privateKey(privateKey: Data(hexString: "0x4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362318")!)) { result in
            expectation.fulfill()
            let wallet = try! result.dematerialize()
            let signResult = keystore.signPersonalMessage("Some data".data(using: .utf8)!, for: wallet.address)
            let data = try! signResult.dematerialize()
            let expected = Data(hexString: "0xb91467e570a6466aa9e9876cbcd013baba02900b8979d43fe208a4a4f339f5fd6007e74cd82e037b800186422fc2da167c747ef045e5d18a5f5d4300f8e1a0291c")
            XCTAssertEqual(expected, data)
        }
        wait(for: [expectation], timeout: 0.01)

        // web3.eth.accounts.sign('Some data', '0x4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362318');
        // expected:
        // message: 'Some data',
        // messageHash: '0x1da44b586eb0729ff70a73c326926f6ed5a25f5b056e7f47fbc6e58d86871655',
        // v: '0x1c',
        // r: '0xb91467e570a6466aa9e9876cbcd013baba02900b8979d43fe208a4a4f339f5fd',
        // s: '0x6007e74cd82e037b800186422fc2da167c747ef045e5d18a5f5d4300f8e1a029',
        // signature: '0xb91467e570a6466aa9e9876cbcd013baba02900b8979d43fe208a4a4f339f5fd6007e74cd82e037b800186422fc2da167c747ef045e5d18a5f5d4300f8e1a0291c'
    }

    func testSignPersonalMessageWithHdWallet() {
        let keystore = FakeEtherKeystore()
        let expectation = self.expectation(description: "completion block called")

        keystore.importWallet(type: .mnemonic(words: ["nuclear", "you", "cage", "screen", "tribe", "trick", "limb", "smart", "dad", "voice", "nut", "jealous"], password: "")) { result in
            expectation.fulfill()
            let wallet = try! result.dematerialize()
            let signResult = keystore.signPersonalMessage("Some data".data(using: .utf8)!, for: wallet.address)
            let data = try! signResult.dematerialize()
            let expected = Data(hexString: "0x03f79a4efa290627cf3e134debd95f6effb60b1119997050fba7f6fd34db17144c8873b8a7a312797623f21a3e69e895d2afe3e1cb334f4bf46c58c5aaab9dac1c")
            XCTAssertEqual(expected, data)
        }
        wait(for: [expectation], timeout: 0.01)
    }

    func testSignMessage() {
        let keystore = FakeEtherKeystore()

        keystore.importWallet(type: .privateKey(privateKey: Data(hexString: "0x4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362318")!)) { result in
            let wallet = try! result.dematerialize()
            let signResult = keystore.signPersonalMessage("0x3f44c2dfea365f01c1ada3b7600db9e2999dfea9fe6c6017441eafcfbc06a543".data(using: .utf8)!, for: wallet.address)
            let data = try! signResult.dematerialize()
            let expected = Data(hexString: "0x619b03743672e31ad1d7ee0e43f6802860082d161acc602030c495a12a68b791666764ca415a2b3083595aee448402874a5a376ea91855051e04c7b3e4693d201c")
            XCTAssertEqual(expected, data)
        }
    }

    func testAddWatchAddress() {
        let keystore = FakeEtherKeystore()
        let address: AlphaWallet.Address = .make()
        keystore.importWallet(type: ImportType.watch(address: address)) { _  in }

        XCTAssertEqual(1, keystore.wallets.count)
        XCTAssertEqual(address, keystore.wallets[0].address)
    }

    func testDeleteWatchAddress() {
        let keystore = FakeEtherKeystore()
        let address: AlphaWallet.Address = .make()

        // TODO. Move this into sync calls
        keystore.importWallet(type: ImportType.watch(address: address)) { result  in
            let wallet = try! result.dematerialize()
            XCTAssertEqual(1, keystore.wallets.count)
            XCTAssertEqual(address, keystore.wallets[0].address)

            let _ = keystore.delete(wallet: wallet)

            XCTAssertEqual(0, keystore.wallets.count)
        }

        XCTAssertEqual(0, keystore.wallets.count)
    }
}
