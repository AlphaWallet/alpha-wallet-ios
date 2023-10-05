// Copyright SIX DAY LLC. All rights reserved.

import Combine
import Foundation
import LocalAuthentication
import AlphaWalletABI
import AlphaWalletTrustWalletCoreExtensions

public protocol Keystore: AnyObject {
    var hasMigratedFromKeystoreFiles: Bool { get }
    var hasWallets: Bool { get }
    var isUserPresenceCheckPossible: Bool { get }
    var wallets: [Wallet] { get }
    var recentlyUsedWallet: Wallet? { get set }
    var currentWallet: Wallet? { get }

    var didAddWallet: AnyPublisher<(wallet: Wallet, event: ImportWalletEvent), Never> { get }
    var didRemoveWallet: AnyPublisher<Wallet, Never> { get }
    var walletsPublisher: AnyPublisher<Set<Wallet>, Never> { get }

    func createHDWallet(seedPhraseCount: HDWallet.SeedPhraseCount, passphrase: String) -> AnyPublisher<Wallet, KeystoreError>
    func watchWallet(address: AlphaWallet.Address) -> AnyPublisher<Wallet, KeystoreError>
    func importWallet(json: String, password: String) -> AnyPublisher<Wallet, KeystoreError>
    func importWallet(mnemonic: [String], passphrase: String) -> AnyPublisher<Wallet, KeystoreError>
    func importWallet(privateKey: Data) -> AnyPublisher<Wallet, KeystoreError>
    func addHardwareWallet(address: AlphaWallet.Address) -> AnyPublisher<Wallet, KeystoreError>

    func elevateSecurity(forAccount account: AlphaWallet.Address, prompt: String) -> Bool
    func exportRawPrivateKeyForNonHdWalletForBackup(forAccount account: AlphaWallet.Address, prompt: String, newPassword: String) -> AnyPublisher<Result<String, KeystoreError>, Never>
    func exportRawPrivateKeyFromHdWallet0thAddressForBackup(forAccount account: AlphaWallet.Address, prompt: String, newPassword: String) -> AnyPublisher<Result<String, KeystoreError>, Never>
    func exportSeedPhraseOfHdWallet(forAccount account: AlphaWallet.Address, context: LAContext, prompt: String) -> AnyPublisher<Result<String, KeystoreError>, Never>
    func verifySeedPhraseOfHdWallet(_ inputSeedPhrase: String, forAccount account: AlphaWallet.Address, prompt: String, context: LAContext) -> AnyPublisher<Result<Bool, KeystoreError>, Never>
    func delete(wallet: Wallet)
    func isProtectedByUserPresence(account: AlphaWallet.Address) -> Bool
    func signPersonalMessage(_ message: Data, for account: AlphaWallet.Address, prompt: String) async -> Result<Data, KeystoreError>
    func signTypedMessage(_ datas: [EthTypedData], for account: AlphaWallet.Address, prompt: String) async -> Result<Data, KeystoreError>
    func signHash(_ hash: Data, for account: AlphaWallet.Address, prompt: String) async -> Result<Data, KeystoreError>
    func signTransaction(_ transaction: UnsignedTransaction, prompt: String) async -> Result<Data, KeystoreError>
    func signEip712TypedData(_ data: EIP712TypedData, for account: AlphaWallet.Address, prompt: String) async -> Result<Data, KeystoreError>
    func signMessageBulk(_ data: [Data], for account: AlphaWallet.Address, prompt: String) async -> Result<[Data], KeystoreError>
    func signMessageData(_ message: Data?, for account: AlphaWallet.Address, prompt: String) async -> Result<Data, KeystoreError>
}

extension Keystore {
    public func createHDWallet() -> AnyPublisher<Wallet, KeystoreError> {
        createHDWallet(seedPhraseCount: .word12, passphrase: "")
    }

    public func createWalletIfMissing() -> AnyPublisher<Void, Never> {
        if !hasWallets {
            return createHDWallet()
                .handleEvents(receiveOutput: { self.recentlyUsedWallet = $0 })
                .mapToVoid()
                .replaceError(with: ())
                .eraseToAnyPublisher()
        } else {
            return.just(())
        }
    }
}
