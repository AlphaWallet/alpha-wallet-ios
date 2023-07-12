// Copyright SIX DAY LLC. All rights reserved.

import XCTest
import LocalAuthentication
@testable import AlphaWallet
import BigInt
import AlphaWalletFoundation
import Combine

class EtherKeystoreTests: XCTestCase {
    private var cancellable = Set<AnyCancellable>()

    func testInitialization() {
        let keystore = FakeEtherKeystore()

        XCTAssertNotNil(keystore)
        XCTAssertEqual(false, keystore.hasWallets)
    }

    func testCreateWallet() {
        let keystore = FakeEtherKeystore()
        let expectation = self.expectation(description: "Wait for a new wallet")
        keystore.createHDWallet()
            .sink(receiveCompletion: { _ in
                expectation.fulfill()
            }, receiveValue: { _ in

                XCTAssertEqual(1, keystore.wallets.count)
            }).store(in: &cancellable)

        wait(for: [expectation], timeout: 20)
    }

    func testEmptyPassword() throws {
        let keystore = try LegacyFileBasedKeystore(securedStorage: KeychainStorage.make())
        let password = keystore.getPassword(for: .make())
        XCTAssertNil(password)
    }

    func testImport() throws {
        let keystore = FakeEtherKeystore()
        let expectation = self.expectation(description: "Wait for a new wallet")
        keystore.importWallet(json: TestKeyStore.keystore, password: TestKeyStore.password)
            .sink(receiveCompletion: { _ in
                expectation.fulfill()
            }, receiveValue: { wallet in

                XCTAssertEqual("0x5E9c27156a612a2D516C74c7a80af107856F8539", wallet.address.eip55String)
                XCTAssertEqual(1, keystore.wallets.count)
            }).store(in: &cancellable)

        wait(for: [expectation], timeout: 20)
    }

    func testImportDuplicate() throws {
        let expectation = self.expectation(description: "Wait for a new wallet")
        let keystore = FakeEtherKeystore(wallets: [.make(address: .make(address: "0x5E9c27156a612a2D516C74c7a80af107856F8539"), origin: .hd)])
        keystore.importWallet(json: TestKeyStore.keystore, password: TestKeyStore.password)
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    if case KeystoreError.duplicateAccount = error {
                        XCTAssertEqual(1, keystore.wallets.count)
                    } else {
                        XCTFail()
                    }
                }
                expectation.fulfill()
            }, receiveValue: { _ in
                XCTFail()
            }).store(in: &cancellable)
        wait(for: [expectation], timeout: 20)
    }

    func testImportFailInvalidPassword() throws {
        let keystore = FakeEtherKeystore()
        let expectation = self.expectation(description: "Wait for a new wallet")
        keystore.importWallet(json: TestKeyStore.keystore, password: "invalidPassword")
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    //no-op
                } else {
                    XCTFail("No error when importing with invalid password")
                }
                XCTAssertEqual(0, keystore.wallets.count)
                expectation.fulfill()
            }, receiveValue: { _ in
                //no-op
            }).store(in: &cancellable)

        wait(for: [expectation], timeout: 20)
    }

    func testExportHdWalletToSeedPhrase() throws {
        let keystore = FakeEtherKeystore()
        let expectation = self.expectation(description: "completion block called")

        keystore.createHDWallet()
            .flatMap { wallet in
                keystore.exportSeedPhraseOfHdWallet(forAccount: wallet.address, context: .init(), prompt: KeystoreExportReason.backup.description)
                    .setFailureType(to: KeystoreError.self)
                    .eraseToAnyPublisher()
            }.sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Failure to import wallet")
                }
                expectation.fulfill()
            }, receiveValue: { result in
                guard let seedPhrase = try? result.get() else {
                    XCTFail("Failure to get seedPhrase")
                    return
                }
                XCTAssertEqual(seedPhrase.split(separator: " ").count, 12)
            }).store(in: &cancellable)

        wait(for: [expectation], timeout: 600)
    }

    func testExportRawPrivateKeyToKeystoreFile() {
        let keystore = FakeEtherKeystore()
        let password = "test"

        XCTAssertEqual(keystore.wallets.count, 0)
        let privateKey = Data(hexString: TestKeyStore.testPrivateKey)!
        let expectation = self.expectation(description: "completion block called")

        func exportRawPrivateKeyForNonHdWalletForBackup(wallet: Wallet) -> AnyPublisher<Result<String, KeystoreError>, KeystoreError> {
            return keystore.exportRawPrivateKeyForNonHdWalletForBackup(forAccount: wallet.address, prompt: R.string.localizable.keystoreAccessKeyNonHdBackup(), newPassword: password)
                .setFailureType(to: KeystoreError.self)
                .eraseToAnyPublisher()
        }

        keystore.importWallet(privateKey: privateKey)
            .flatMap { wallet in
                XCTAssertEqual(keystore.wallets.count, 1)
                return exportRawPrivateKeyForNonHdWalletForBackup(wallet: wallet)
            }.sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Failure to import wallet")
                }
                expectation.fulfill()
            }, receiveValue: { result in
                let v = try? result.get()
                XCTAssertNotNil(v)
            }).store(in: &cancellable)

        wait(for: [expectation], timeout: 600)
    }

    func testRecentlyUsedAccount() throws {
        let keystore = FakeEtherKeystore()

        XCTAssertNil(keystore.recentlyUsedWallet)
        let expectation = self.expectation(description: "Wait for a new wallet")
        keystore.createHDWallet()
            .sink(receiveCompletion: { result in
                if case .failure(let e) = result {
                    XCTFail(e.localizedDescription)
                }
                expectation.fulfill()
            }, receiveValue: { account in
                keystore.recentlyUsedWallet = account

                XCTAssertEqual(account, keystore.recentlyUsedWallet)
                XCTAssertEqual(account, keystore.currentWallet)

                keystore.recentlyUsedWallet = nil

                XCTAssertNil(keystore.recentlyUsedWallet)
            }).store(in: &cancellable)

        wait(for: [expectation], timeout: 20)
    }

    func testDeleteAccount() throws {
        let keystore = FakeEtherKeystore()
        let expectation = self.expectation(description: "Wait for a new wallet")
        keystore.createHDWallet()
            .sink(receiveCompletion: { result in
                if case .failure(let e) = result {
                    XCTFail(e.localizedDescription)
                }
                expectation.fulfill()
            }, receiveValue: { wallet in
                XCTAssertEqual(1, keystore.wallets.count)

                keystore.delete(wallet: wallet)

                XCTAssertTrue(keystore.wallets.isEmpty)
            }).store(in: &cancellable)

        wait(for: [expectation], timeout: 20)
    }

    func testConvertPrivateKeyToKeyStore() throws {
        let passphrase = "MyHardPassword!"
        let keyResult = (try! LegacyFileBasedKeystore(securedStorage: KeychainStorage.make())).convertPrivateKeyToKeystoreFile(privateKey: Data(hexString: TestKeyStore.testPrivateKey)!, passphrase: passphrase)
        let dict = try keyResult.get()

        let keystore = FakeEtherKeystore()
        let expectation = self.expectation(description: "Wait for a new wallet")
        keystore.importWallet(json: dict.jsonString!, password: passphrase)
            .sink(receiveCompletion: { result in
                if case .failure(let e) = result {
                    XCTFail(e.localizedDescription)
                }
                expectation.fulfill()
            }, receiveValue: { wallet in
                XCTAssertEqual(wallet.address.eip55String, "0x95fc7381950Db9d7ab116099c4E84AFD686e3e9C")
                XCTAssertEqual(1, keystore.wallets.count)
            }).store(in: &cancellable)

        wait(for: [expectation], timeout: 20)
    }

    func testSignPersonalMessageWithRawPrivateKey() throws {
        let privateKey = Data(hexString: "0x4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362318")!
        let keystore = FakeEtherKeystore()
        let expectation = self.expectation(description: "Wait for a new wallet")
        keystore.importWallet(privateKey: privateKey)
            .sink(receiveCompletion: { result in
                if case .failure(let e) = result {
                    XCTFail(e.localizedDescription)
                }
                expectation.fulfill()
            }, receiveValue: { wallet in
                Task {
                    let signResult = await keystore.signPersonalMessage(Data("Some data".utf8), for: wallet.address, prompt: R.string.localizable.keystoreAccessKeySign())
                    guard let data = try? signResult.get() else {
                        XCTFail("Failure to import wallet")
                        return
                    }
                    let expected = Data(hexString: "0xb91467e570a6466aa9e9876cbcd013baba02900b8979d43fe208a4a4f339f5fd6007e74cd82e037b800186422fc2da167c747ef045e5d18a5f5d4300f8e1a0291c")
                    XCTAssertEqual(expected, data)
                }
            }).store(in: &cancellable)

        wait(for: [expectation], timeout: 20)

        // web3.eth.accounts.sign('Some data', '0x4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362318');
        // expected:
        // message: 'Some data',
        // messageHash: '0x1da44b586eb0729ff70a73c326926f6ed5a25f5b056e7f47fbc6e58d86871655',
        // v: '0x1c',
        // r: '0xb91467e570a6466aa9e9876cbcd013baba02900b8979d43fe208a4a4f339f5fd',
        // s: '0x6007e74cd82e037b800186422fc2da167c747ef045e5d18a5f5d4300f8e1a029',
        // signature: '0xb91467e570a6466aa9e9876cbcd013baba02900b8979d43fe208a4a4f339f5fd6007e74cd82e037b800186422fc2da167c747ef045e5d18a5f5d4300f8e1a0291c'
    }

    func testSignPersonalMessageWithHdWallet() throws {
        let keystore = FakeEtherKeystore()
        let words = ["nuclear", "you", "cage", "screen", "tribe", "trick", "limb", "smart", "dad", "voice", "nut", "jealous"]

        let expectation = self.expectation(description: "Wait for a new wallet")
        keystore.importWallet(mnemonic: words, passphrase: "")
            .sink(receiveCompletion: { result in
                if case .failure(let e) = result {
                    XCTFail(e.localizedDescription)
                }
                expectation.fulfill()
            }, receiveValue: { wallet in
                Task {
                    let signResult = await keystore.signPersonalMessage(Data("Some data".utf8), for: wallet.address, prompt: R.string.localizable.keystoreAccessKeySign())
                    guard let data = try? signResult.get() else {
                        XCTFail("Failure to import wallet")
                        return
                    }
                    let expected = Data(hexString: "0x03f79a4efa290627cf3e134debd95f6effb60b1119997050fba7f6fd34db17144c8873b8a7a312797623f21a3e69e895d2afe3e1cb334f4bf46c58c5aaab9dac1c")
                    XCTAssertEqual(expected, data)
                }
            }).store(in: &cancellable)

        wait(for: [expectation], timeout: 20)
    }

    func testSignMessage() throws {
        let keystore = FakeEtherKeystore()
        let privateKey = Data(hexString: "0x4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362318")!

        let expectation = self.expectation(description: "Wait for a new wallet")
        keystore.importWallet(privateKey: privateKey)
            .sink(receiveCompletion: { result in
                if case .failure(let e) = result {
                    XCTFail(e.localizedDescription)
                }
                expectation.fulfill()
            }, receiveValue: { wallet in
                Task {
                    let signResult = await keystore.signPersonalMessage(Data("0x3f44c2dfea365f01c1ada3b7600db9e2999dfea9fe6c6017441eafcfbc06a543".utf8), for: wallet.address, prompt: R.string.localizable.keystoreAccessKeySign())
                    guard let data = try? signResult.get() else {
                        XCTFail("Failure to import wallet")
                        return
                    }
                    let expected = Data(hexString: "0x619b03743672e31ad1d7ee0e43f6802860082d161acc602030c495a12a68b791666764ca415a2b3083595aee448402874a5a376ea91855051e04c7b3e4693d201c")
                    XCTAssertEqual(expected, data)
                }
            }).store(in: &cancellable)

        wait(for: [expectation], timeout: 20)
    }

    func testAddWatchAddress() throws {
        let keystore = FakeEtherKeystore()
        let address: AlphaWallet.Address = .make()

        let expectation = self.expectation(description: "Wait for a new wallet")
        keystore.watchWallet(address: address)
            .sink(receiveCompletion: { result in
                if case .failure(let e) = result {
                    XCTFail(e.localizedDescription)
                }
                expectation.fulfill()
            }, receiveValue: { _ in
                XCTAssertEqual(1, keystore.wallets.count)
                XCTAssertEqual(address, keystore.wallets[0].address)
            }).store(in: &cancellable)

        wait(for: [expectation], timeout: 20)
    }

    func testDeleteWatchAddress() throws {
        let keystore = FakeEtherKeystore()
        let address: AlphaWallet.Address = .make()

        let expectation = self.expectation(description: "Wait for a new wallet")
        keystore.watchWallet(address: address)
            .sink(receiveCompletion: { result in
                if case .failure(let e) = result {
                    XCTFail(e.localizedDescription)
                }
                expectation.fulfill()
            }, receiveValue: { wallet in
                XCTAssertEqual(1, keystore.wallets.count)
                XCTAssertEqual(address, keystore.wallets[0].address)

                let _ = keystore.delete(wallet: wallet)

                XCTAssertEqual(0, keystore.wallets.count)
            }).store(in: &cancellable)

        wait(for: [expectation], timeout: 20)
    }
}
