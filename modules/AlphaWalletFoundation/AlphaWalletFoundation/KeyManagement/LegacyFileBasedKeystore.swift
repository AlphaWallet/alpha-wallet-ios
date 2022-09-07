// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import Foundation
import CryptoSwift
import TrustKeystore

public enum FileBasedKeystoreError: LocalizedError {
    case protectionDisabled
}
fileprivate typealias LegacyKeyStore = TrustKeystore.KeyStore

public class LegacyFileBasedKeystore {
    private let securedStorage: SecuredStorage
    private let datadir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    private let keyStore: LegacyKeyStore
    private let etherkeystore: Keystore
    let keystoreDirectory: URL

    public init(securedStorage: SecuredStorage, keyStoreSubfolder: String = "/keystore", keystore: Keystore) throws {
        self.keystoreDirectory = URL(fileURLWithPath: datadir + keyStoreSubfolder)
        self.securedStorage = securedStorage
        self.keyStore = try LegacyKeyStore(keydir: keystoreDirectory)
        self.etherkeystore = keystore
    }

    public func getPrivateKeyFromKeystoreFile(json: String, password: String) -> Result<Data, KeystoreError> {
        guard let data = json.data(using: .utf8) else { return .failure(.failedToDecryptKey) }
        guard let key = try? JSONDecoder().decode(KeystoreKey.self, from: data) else { return .failure(.failedToImportPrivateKey) }
        guard let privateKey = try? key.decrypt(password: password) else { return .failure(.failedToDecryptKey) }
        return .success(privateKey)
    }

    public func export(privateKey: Data, newPassword: String) -> Result<String, KeystoreError> {
        switch convertPrivateKeyToKeystoreFile(privateKey: privateKey, passphrase: newPassword) {
        case .success(let dict):
            if let jsonString = dict.jsonString {
                return .success(jsonString)
            } else {
                return .failure(.failedToExportPrivateKey)
            }
        case .failure:
            return .failure(.failedToExportPrivateKey)
        }
    }

    private func exportPrivateKey(account: AlphaWallet.Address) -> Result<Data, KeystoreError> {
        guard let password = getPassword(for: account) else { return .failure(KeystoreError.accountNotFound) }
        guard let account = getAccount(forAddress: account) else { return .failure(.accountNotFound) }
        do {
            let privateKey = try keyStore.exportPrivateKey(account: account, password: password)
            return .success(privateKey)
        } catch {
            return .failure(KeystoreError.failedToExportPrivateKey)
        }
    }

    @discardableResult public func delete(wallet: Wallet) -> Result<Void, KeystoreError> {
        switch wallet.type {
        case .real(let address):
            guard let account = getAccount(forAddress: address) else { return .failure(.accountNotFound) }
            guard let password = getPassword(for: address) else { return .failure(.failedToDeleteAccount) }

            do {
                try keyStore.delete(account: account, password: password)
                return .success(())
            } catch {
                return .failure(.failedToDeleteAccount)
            }
        case .watch:
            return .success(())
        }
    }

    public func getPassword(for account: AlphaWallet.Address) -> String? {
        //This has to be lowercased due to legacy reasons — it had been written to as lowercased() earlier
        return securedStorage.get(account.eip55String.lowercased(), prompt: nil, withContext: nil)
    }

    public func getAccount(forAddress address: AlphaWallet.Address) -> Account? {
        return keyStore.account(for: .init(address: address))
    }

    public func convertPrivateKeyToKeystoreFile(privateKey: Data, passphrase: String) -> Result<[String: Any], KeystoreError> {
        do {
            let key = try KeystoreKey(password: passphrase, key: privateKey)
            let data = try JSONEncoder().encode(key)
            let dict = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
            return .success(dict)
        } catch {
            return .failure(KeystoreError.failedToImportPrivateKey)
        }
    }

    public func migrateKeystoreFilesToRawPrivateKeysInKeychain() {
        guard !etherkeystore.hasMigratedFromKeystoreFiles else { return }

        for each in keyStore.accounts {
            switch exportPrivateKey(account: AlphaWallet.Address(address: each.address)) {
            case .success(let privateKey):
                etherkeystore.importWallet(type: .privateKey(privateKey: privateKey), completion: { _ in })
            case .failure:
                break
            }
        }
    }
}
