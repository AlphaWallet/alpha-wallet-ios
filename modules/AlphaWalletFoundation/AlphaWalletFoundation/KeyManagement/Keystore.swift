// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import LocalAuthentication
import Combine

public protocol Keystore {
    var hasMigratedFromKeystoreFiles: Bool { get }
    var hasWallets: Bool { get }
    var isUserPresenceCheckPossible: Bool { get }
    var wallets: [Wallet] { get }
    var recentlyUsedWallet: Wallet? { get set }
    var currentWallet: Wallet? { get }

    func createAccount(completion: @escaping (Result<Wallet, KeystoreError>) -> Void)
    func importWallet(type: ImportType) -> Result<Wallet, KeystoreError>
    func elevateSecurity(forAccount account: AlphaWallet.Address, prompt: String) -> Bool
    func exportRawPrivateKeyForNonHdWalletForBackup(forAccount account: AlphaWallet.Address, prompt: String, newPassword: String) -> AnyPublisher<Result<String, KeystoreError>, Never>
    func exportRawPrivateKeyFromHdWallet0thAddressForBackup(forAccount account: AlphaWallet.Address, prompt: String, newPassword: String) -> AnyPublisher<Result<String, KeystoreError>, Never>
    func exportSeedPhraseOfHdWallet(forAccount account: AlphaWallet.Address, context: LAContext, prompt: String) -> AnyPublisher<Result<String, KeystoreError>, Never>
    func verifySeedPhraseOfHdWallet(_ inputSeedPhrase: String, forAccount account: AlphaWallet.Address, prompt: String, context: LAContext) -> AnyPublisher<Result<Bool, KeystoreError>, Never>
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

extension Keystore {
    public mutating func createWalletIfMissing() {
        if !hasWallets {
            switch importWallet(type: .newWallet) {
            case .success(let account):
                recentlyUsedWallet = account
            case .failure:
                break //TODO handle initial wallet creation error. App can't be used!
            }
        }
    }
}
