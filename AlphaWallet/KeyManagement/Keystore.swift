// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import Result

protocol Keystore {
    static var current: Wallet? { get }

    var hasWallets: Bool { get }
    var wallets: [Wallet] { get }
    var recentlyUsedWallet: Wallet? { get set }

    @available(iOS 10.0, *)
    func createAccount(completion: @escaping (Result<EthereumAccount, KeystoreError>) -> Void)
    func importWallet(type: ImportType, completion: @escaping (Result<Wallet, KeystoreError>) -> Void)
    func createAccount() -> Result<EthereumAccount, KeystoreError>
    func exportRawPrivateKeyForNonHdWallet(forAccount: EthereumAccount, newPassword: String, completion: @escaping (Result<String, KeystoreError>) -> Void)
    func exportSeedPhraseHdWallet(forAccount account: EthereumAccount, completion: @escaping (Result<String, KeystoreError>) -> Void)
    func verifySeedPhraseOfHdWallet(_ seedPhrase: String, forAccount account: EthereumAccount, completion: @escaping (Result<Bool, KeystoreError>) -> Void)
    func delete(wallet: Wallet, completion: @escaping (Result<Void, KeystoreError>) -> Void)
    func isHdWallet(account: EthereumAccount) -> Bool
    func isHdWallet(wallet: Wallet) -> Bool
    func isKeystore(wallet: Wallet) -> Bool
    func isWatched(wallet: Wallet) -> Bool
    func signPersonalMessage(_ data: Data, for account: EthereumAccount) -> Result<Data, KeystoreError>
    func signTypedMessage(_ datas: [EthTypedData], for account: EthereumAccount) -> Result<Data, KeystoreError>
    func signMessage(_ data: Data, for account: EthereumAccount) -> Result<Data, KeystoreError>
    func signHash(_ data: Data, for account: EthereumAccount) -> Result<Data, KeystoreError>
    func signTransaction(_ signTransaction: UnsignedTransaction) -> Result<Data, KeystoreError>
}
