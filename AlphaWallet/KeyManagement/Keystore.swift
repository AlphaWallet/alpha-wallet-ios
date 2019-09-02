// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import LocalAuthentication
import Result

enum KeystoreExportReason {
    case backup
    case prepareForVerification

    var prompt: String {
        switch self {
        case .backup:
            return R.string.localizable.keystoreAccessKeyHdBackup()
        case .prepareForVerification:
            return R.string.localizable.keystoreAccessKeyHdPrepareToVerify()
        }
    }
}

protocol Keystore {
    static var current: Wallet? { get }

    var hasWallets: Bool { get }
    var isUserPresenceCheckPossible: Bool { get }
    var wallets: [Wallet] { get }
    var recentlyUsedWallet: Wallet? { get set }

    @available(iOS 10.0, *)
    func createAccount(completion: @escaping (Result<EthereumAccount, KeystoreError>) -> Void)
    func importWallet(type: ImportType, completion: @escaping (Result<Wallet, KeystoreError>) -> Void)
    func createAccount() -> Result<EthereumAccount, KeystoreError>
    func elevateSecurity(forAccount account: EthereumAccount) -> Bool
    func exportRawPrivateKeyForNonHdWalletForBackup(forAccount: EthereumAccount, newPassword: String, completion: @escaping (Result<String, KeystoreError>) -> Void)
    func exportSeedPhraseOfHdWallet(forAccount account: EthereumAccount, context: LAContext, reason: KeystoreExportReason, completion: @escaping (Result<String, KeystoreError>) -> Void)
    func verifySeedPhraseOfHdWallet(_ inputSeedPhrase: String, forAccount account: EthereumAccount, context: LAContext, completion: @escaping (Result<Bool, KeystoreError>) -> Void)
    func delete(wallet: Wallet, completion: @escaping (Result<Void, KeystoreError>) -> Void)
    func isHdWallet(account: EthereumAccount) -> Bool
    func isHdWallet(wallet: Wallet) -> Bool
    func isKeystore(wallet: Wallet) -> Bool
    func isWatched(wallet: Wallet) -> Bool
    func isProtectedByUserPresence(account: EthereumAccount) -> Bool
    func signPersonalMessage(_ data: Data, for account: EthereumAccount) -> Result<Data, KeystoreError>
    func signTypedMessage(_ datas: [EthTypedData], for account: EthereumAccount) -> Result<Data, KeystoreError>
    func signMessage(_ data: Data, for account: EthereumAccount) -> Result<Data, KeystoreError>
    func signHash(_ data: Data, for account: EthereumAccount) -> Result<Data, KeystoreError>
    func signTransaction(_ signTransaction: UnsignedTransaction) -> Result<Data, KeystoreError>
}
