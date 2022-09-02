// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import LocalAuthentication

public protocol KeystoreDelegate: AnyObject {
    func didImport(wallet: Wallet, in keystore: Keystore)
}

public protocol Keystore {
    var delegate: KeystoreDelegate? { get set }
    var hasMigratedFromKeystoreFiles: Bool { get }
    var hasWallets: Bool { get }
    var isUserPresenceCheckPossible: Bool { get }
    var wallets: [Wallet] { get }
    var recentlyUsedWallet: Wallet? { get set }
    var currentWallet: Wallet? { get }

    func createAccount(completion: @escaping (Result<Wallet, KeystoreError>) -> Void)
    func importWallet(type: ImportType, completion: @escaping (Result<Wallet, KeystoreError>) -> Void)
    func createAccount() -> Result<Wallet, KeystoreError>
    func elevateSecurity(forAccount account: AlphaWallet.Address, prompt: String) -> Bool
    func exportRawPrivateKeyForNonHdWalletForBackup(forAccount account: AlphaWallet.Address, prompt: String, newPassword: String, completion: @escaping (Result<String, KeystoreError>) -> Void)
    func exportRawPrivateKeyFromHdWallet0thAddressForBackup(forAccount account: AlphaWallet.Address, prompt: String, newPassword: String, completion: @escaping (Result<String, KeystoreError>) -> Void)
    func exportSeedPhraseOfHdWallet(forAccount account: AlphaWallet.Address, context: LAContext, prompt: String, completion: @escaping (Result<String, KeystoreError>) -> Void)
    func verifySeedPhraseOfHdWallet(_ inputSeedPhrase: String, forAccount account: AlphaWallet.Address, prompt: String, context: LAContext, completion: @escaping (Result<Bool, KeystoreError>) -> Void)
    func delete(wallet: Wallet) -> Result<Void, KeystoreError>
    func isProtectedByUserPresence(account: AlphaWallet.Address) -> Bool
    func signPersonalMessage(_ message: Data, for account: AlphaWallet.Address, prompt: String) -> Result<Data, KeystoreError>
    func signTypedMessage(_ datas: [EthTypedData], for account: AlphaWallet.Address, prompt: String) -> Result<Data, KeystoreError>
    func signMessage(_ message: Data, for account: AlphaWallet.Address, prompt: String) -> Result<Data, KeystoreError>
    func signHash(_ hash: Data, for account: AlphaWallet.Address, prompt: String) -> Result<Data, KeystoreError>
    func signTransaction(_ transaction: UnsignedTransaction, prompt: String) -> Result<Data, KeystoreError>
    func signEip712TypedData(_ data: EIP712TypedData, for account: AlphaWallet.Address, prompt: String) -> Result<Data, KeystoreError>
    func signMessageBulk(_ data: [Data], for account: AlphaWallet.Address, prompt: String) -> Result<[Data], KeystoreError>
    func signMessageData(_ message: Data?, for account: AlphaWallet.Address, prompt: String) -> Result<Data, KeystoreError>
}
