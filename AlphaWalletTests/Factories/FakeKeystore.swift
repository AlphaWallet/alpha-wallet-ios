// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import LocalAuthentication
@testable import AlphaWallet
import TrustKeystore
import Result

struct FakeKeystore: Keystore {
    static var current: Wallet?

    enum AssumeAllWalletsType {
        case hdWallet
        case keyStoreWallet
    }

    private let assumeAllWalletsType: AssumeAllWalletsType

    var hasWallets: Bool {
        return !wallets.isEmpty
    }
    var isUserPresenceCheckPossible: Bool {
        return true
    }
    var wallets: [Wallet]
    var recentlyUsedWallet: Wallet?

    init(wallets: [Wallet] = [], recentlyUsedWallet: Wallet? = .none, assumeAllWalletsType: AssumeAllWalletsType = .hdWallet) {
        self.wallets = wallets
        self.recentlyUsedWallet = recentlyUsedWallet
        self.assumeAllWalletsType = assumeAllWalletsType
    }

    func verifySeedPhraseOfHdWallet(_ inputSeedPhrase: String, forAccount account: EthereumAccount, context: LAContext, completion: @escaping (Result<Bool, KeystoreError>) -> Void) {
    }

    func isHdWallet(wallet: Wallet) -> Bool {
        switch assumeAllWalletsType {
        case .hdWallet:
            return true
        case .keyStoreWallet:
            return false
        }
    }

    func isKeystore(wallet: Wallet) -> Bool {
        switch assumeAllWalletsType {
        case .hdWallet:
            return false
        case .keyStoreWallet:
            return true
        }
    }

    func isWatched(wallet: Wallet) -> Bool {
        return false
    }

    func isProtectedByUserPresence(account: EthereumAccount) -> Bool {
        return false
    }

    func importWallet(type: ImportType, completion: @escaping (Result<Wallet, KeystoreError>) -> Void) {
    }

    func delete(wallet: Wallet, completion: @escaping (Result<Void, KeystoreError>) -> Void) {
        completion(.failure(KeystoreError.failedToSignTransaction))
    }

    func isHdWallet(account: EthereumAccount) -> Bool {
        switch assumeAllWalletsType {
        case .hdWallet:
            return true
        case .keyStoreWallet:
            return false
        }
    }

    func signHash(_ data: Data, for account: EthereumAccount) -> Result<Data, KeystoreError> {
        return .failure(KeystoreError.failedToSignMessage)
    }

    func signPersonalMessage(_ data: Data, for account: EthereumAccount) -> Result<Data, KeystoreError> {
        return .failure(KeystoreError.failedToSignTransaction)
    }

    func signMessage(_ data: Data, for account: EthereumAccount) -> Result<Data, KeystoreError> {
        return .failure(KeystoreError.failedToSignMessage)
    }

    func signTransaction(_ signTransaction: UnsignedTransaction) -> Result<Data, KeystoreError> {
        return .failure(KeystoreError.failedToSignTransaction)
    }

    func signTypedMessage(_ datas: [EthTypedData], for account: EthereumAccount) -> Result<Data, KeystoreError> {
        return .failure(KeystoreError.failedToSignMessage)
    }

    func createAccount(completion: @escaping (Result<EthereumAccount, KeystoreError>) -> Void) {
    }

    func createAccount() -> Result<EthereumAccount, KeystoreError> {
        return .success(.make())
    }

    func elevateSecurity(forAccount account: EthereumAccount) -> Bool {
        return false
    }

    func exportRawPrivateKeyForNonHdWalletForBackup(forAccount: EthereumAccount, newPassword: String, completion: @escaping (Result<String, KeystoreError>) -> Void) {
    }

    func exportSeedPhraseOfHdWallet(forAccount account: EthereumAccount, context: LAContext, reason: KeystoreExportReason, completion: @escaping (Result<String, KeystoreError>) -> Void) {
    }
}

extension FakeKeystore {
    static func make(
        wallets: [Wallet] = [],
        recentlyUsedWallet: Wallet? = .none
    ) -> FakeKeystore {
        return FakeKeystore(
            wallets: wallets,
            recentlyUsedWallet: recentlyUsedWallet
        )
    }
}
