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
    //TODO remove this if possible, replacing with the instance-side version
    static var currentWallet: Wallet { get }

    var hasWallets: Bool { get }
    var isUserPresenceCheckPossible: Bool { get }
    var subscribableWallets: Subscribable<Set<Wallet>> { get }
    var wallets: [Wallet] { get }
    var recentlyUsedWallet: Wallet? { get set }
    var currentWallet: Wallet { get }

    func createAccount(completion: @escaping (Result<AlphaWallet.Address, KeystoreError>) -> Void)
    func importWallet(type: ImportType, completion: @escaping (Result<Wallet, KeystoreError>) -> Void)
    func createAccount() -> Result<AlphaWallet.Address, KeystoreError>
    func elevateSecurity(forAccount account: AlphaWallet.Address) -> Bool
    func exportRawPrivateKeyForNonHdWalletForBackup(forAccount: AlphaWallet.Address, newPassword: String, completion: @escaping (Result<String, KeystoreError>) -> Void)
    func exportRawPrivateKeyFromHdWallet0thAddressForBackup(forAccount: AlphaWallet.Address, newPassword: String, completion: @escaping (Result<String, KeystoreError>) -> Void)
    func exportSeedPhraseOfHdWallet(forAccount account: AlphaWallet.Address, context: LAContext, reason: KeystoreExportReason, completion: @escaping (Result<String, KeystoreError>) -> Void)
    func verifySeedPhraseOfHdWallet(_ inputSeedPhrase: String, forAccount account: AlphaWallet.Address, context: LAContext, completion: @escaping (Result<Bool, KeystoreError>) -> Void)
    func delete(wallet: Wallet) -> Result<Void, KeystoreError>
    func isHdWallet(account: AlphaWallet.Address) -> Bool
    func isHdWallet(wallet: Wallet) -> Bool
    func isKeystore(wallet: Wallet) -> Bool
    func isWatched(wallet: Wallet) -> Bool
    func isProtectedByUserPresence(account: AlphaWallet.Address) -> Bool
    func signPersonalMessage(_ data: Data, for account: AlphaWallet.Address) -> Result<Data, KeystoreError>
    func signTypedMessage(_ datas: [EthTypedData], for account: AlphaWallet.Address) -> Result<Data, KeystoreError>
    func signMessage(_ data: Data, for account: AlphaWallet.Address) -> Result<Data, KeystoreError>
    func signHash(_ data: Data, for account: AlphaWallet.Address) -> Result<Data, KeystoreError>
    func signTransaction(_ signTransaction: UnsignedTransaction) -> Result<Data, KeystoreError>
    func signEip712TypedData(_ data: EIP712TypedData, for account: AlphaWallet.Address) -> Result<Data, KeystoreError>
}
