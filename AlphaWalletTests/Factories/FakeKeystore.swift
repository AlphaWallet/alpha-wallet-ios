// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import LocalAuthentication
@testable import AlphaWallet
import TrustKeystore
import Result

struct FakeKeystore: Keystore {

    static var currentWallet: Wallet {
        Wallet(type: .watch(.makeStormBird()))
    }

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
    var subscribableWallets: Subscribable<Set<Wallet>>
    var currentWallet: Wallet {
        //Better crash now instead of populating callers with optionals
        if let wallet = recentlyUsedWallet {
            return wallet
        } else if wallets.count == 1 {
            return wallets.first!
        } else {
            fatalError("No wallet")
        }
    }

    init(wallets: [Wallet] = [], recentlyUsedWallet: Wallet? = .none, assumeAllWalletsType: AssumeAllWalletsType = .hdWallet) {
        self.wallets = wallets
        self.recentlyUsedWallet = recentlyUsedWallet ?? FakeKeystore.currentWallet
        self.assumeAllWalletsType = assumeAllWalletsType
        self.subscribableWallets = .init(Set(wallets))
    }

    func verifySeedPhraseOfHdWallet(_ inputSeedPhrase: String, forAccount account: AlphaWallet.Address, context: LAContext, completion: @escaping (Result<Bool, KeystoreError>) -> Void) {
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

    func isProtectedByUserPresence(account: AlphaWallet.Address) -> Bool {
        return false
    }

    func importWallet(type: ImportType, completion: @escaping (Result<Wallet, KeystoreError>) -> Void) {
    }

    func delete(wallet: Wallet) -> Result<Void, KeystoreError> {
        .failure(KeystoreError.failedToSignTransaction)
    }

    func isHdWallet(account: AlphaWallet.Address) -> Bool {
        switch assumeAllWalletsType {
        case .hdWallet:
            return true
        case .keyStoreWallet:
            return false
        }
    }

    func signHash(_ data: Data, for account: AlphaWallet.Address) -> Result<Data, KeystoreError> {
        return .failure(KeystoreError.failedToSignMessage)
    }

    func signPersonalMessage(_ data: Data, for account: AlphaWallet.Address) -> Result<Data, KeystoreError> {
        return .failure(KeystoreError.failedToSignTransaction)
    }

    func signEip712TypedData(_ data: EIP712TypedData, for account: AlphaWallet.Address) -> Result<Data, KeystoreError> {
        return .failure(KeystoreError.failedToSignMessage)
    }

    func signMessage(_ data: Data, for account: AlphaWallet.Address) -> Result<Data, KeystoreError> {
        return .failure(KeystoreError.failedToSignMessage)
    }

    func signTransaction(_ signTransaction: UnsignedTransaction) -> Result<Data, KeystoreError> {
        return .failure(KeystoreError.failedToSignTransaction)
    }

    func signTypedMessage(_ datas: [EthTypedData], for account: AlphaWallet.Address) -> Result<Data, KeystoreError> {
        return .failure(KeystoreError.failedToSignMessage)
    }

    func createAccount(completion: @escaping (Result<AlphaWallet.Address, KeystoreError>) -> Void) {
    }

    func createAccount() -> Result<AlphaWallet.Address, KeystoreError> {
        return .success(.make())
    }

    func elevateSecurity(forAccount account: AlphaWallet.Address) -> Bool {
        return false
    }

    func exportRawPrivateKeyForNonHdWalletForBackup(forAccount: AlphaWallet.Address, newPassword: String, completion: @escaping (Result<String, KeystoreError>) -> Void) {
    }

    func exportRawPrivateKeyFromHdWallet0thAddressForBackup(forAccount: AlphaWallet.Address, newPassword: String, completion: @escaping (Result<String, KeystoreError>) -> Void) {
    }

    func exportSeedPhraseOfHdWallet(forAccount account: AlphaWallet.Address, context: LAContext, reason: KeystoreExportReason, completion: @escaping (Result<String, KeystoreError>) -> Void) {
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
