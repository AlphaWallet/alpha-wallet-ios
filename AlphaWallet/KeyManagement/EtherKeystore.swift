// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import LocalAuthentication
import BigInt
import KeychainSwift
import Result
import WalletCore
import web3swift

enum EtherKeystoreError: LocalizedError {
    case protectionDisabled
}

// swiftlint:disable type_body_length
///We use ECDSA keys (created and stored in the Secure Enclave), achieving symmetric encryption based on Diffie-Hellman to encrypt the HD wallet seed and raw private keys and store the ciphertext in the keychain.
//
//There are 2 sets of (ECDSA key and ciphertext) for each Ethereum raw private key or HD wallet seed. 1 set is stored requiring user presence for access and the other doesn't. The second set is needed to ensure the user has does not lose access to the Ethereum raw private key (or HD wallet seed) when they delete their iOS passcode. Once the user has verified that they have backed up their wallet, they can choose to elevate the security of their wallet which deletes the set of (ECDSA key and ciphertext) that do not require user-presence.
//
//Technically, having 2 sets of (ECDSA key and ciphertext) for each Ethereum raw private key or HD wallet seed may not be required for iOS. But it is done:
//(A) to be confident that we don't cause the user to lose access to their wallets and
///(B) to be consistent with Android's UI and implementation which seems like users will lose access to the data (i.e wallet) which requires user presence if the equivalent of their iOS passcode/biometrics is disabled/deleted
open class EtherKeystore: NSObject, Keystore {
    private struct Keys {
        static let recentlyUsedAddress: String = "recentlyUsedAddress"
        static let watchAddresses = "watchAddresses"
        static let ethereumAddressesWithPrivateKeys = "ethereumAddressesWithPrivateKeys"
        static let ethereumAddressesWithSeed = "ethereumAddressesWithSeed"
        static let ethereumAddressesProtectedByUserPresence = "ethereumAddressesProtectedByUserPresence"
        static let ethereumRawPrivateKeyUserPresenceNotRequiredPrefix = "ethereumRawPrivateKeyUserPresenceNotRequired-"
        static let ethereumSeedUserPresenceNotRequiredPrefix = "ethereumSeedUserPresenceNotRequired-"
        static let ethereumRawPrivateKeyUserPresenceRequiredPrefix = "ethereumRawPrivateKeyUserPresenceRequired-"
        static let ethereumSeedUserPresenceRequiredPrefix = "ethereumSeedUserPresenceRequired-"
        //These aren't actually the label for the encryption key, but rather, the label for the ECDSA keys that will be used to generate the AES encryption keys since iOS Secure Enclave only supports ECDSA and not AES
        static let encryptionKeyForSeedUserPresenceRequiredPrefix = "encryptionKeyForSeedUserPresenceRequired-"
        static let encryptionKeyForPrivateKeyUserPresenceRequiredPrefix = "encryptionKeyForPrivateKeyUserPresenceRequired-"
        static let encryptionKeyForSeedUserPresenceNotRequiredPrefix = "encryptionKeyForSeedUserPresenceNotRequired-"
        static let encryptionKeyForPrivateKeyUserPresenceNotRequiredPrefix = "encryptionKeyForPrivateKeyUserPresenceNotRequired-"
    }

    enum WalletSeedOrKey {
        case key(Data)
        case seed(String)
        case seedPhrase(String)
        case userCancelled
        case notFound
        case otherFailure
    }

    private let emptyPassphrase = ""
    private let keychain: KeychainSwift
    private let defaultKeychainAccessUserPresenceRequired: KeychainSwiftAccessOptions = .accessibleWhenUnlockedThisDeviceOnly(userPresenceRequired: true)
    private let defaultKeychainAccessUserPresenceNotRequired: KeychainSwiftAccessOptions = .accessibleWhenUnlockedThisDeviceOnly(userPresenceRequired: false)
    private let userDefaults: UserDefaults
    private var watchAddresses: [String] {
        get {
            guard let data = userDefaults.data(forKey: Keys.watchAddresses) else {
                return []
            }
            return NSKeyedUnarchiver.unarchiveObject(with: data) as? [String] ?? []
        }
        set {
            let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            return userDefaults.set(data, forKey: Keys.watchAddresses)
        }
    }

    private var ethereumAddressesWithPrivateKeys: [String] {
        get {
            guard let data = userDefaults.data(forKey: Keys.ethereumAddressesWithPrivateKeys) else {
                return []
            }
            return NSKeyedUnarchiver.unarchiveObject(with: data) as? [String] ?? []
        }
        set {
            let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            return userDefaults.set(data, forKey: Keys.ethereumAddressesWithPrivateKeys)
        }
    }

    private var ethereumAddressesWithSeed: [String] {
        get {
            guard let data = userDefaults.data(forKey: Keys.ethereumAddressesWithSeed) else {
                return []
            }
            return NSKeyedUnarchiver.unarchiveObject(with: data) as? [String] ?? []
        }
        set {
            let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            return userDefaults.set(data, forKey: Keys.ethereumAddressesWithSeed)
        }
    }

    private var ethereumAddressesProtectedByUserPresence: [String] {
        get {
            guard let data = userDefaults.data(forKey: Keys.ethereumAddressesProtectedByUserPresence) else {
                return []
            }

            return NSKeyedUnarchiver.unarchiveObject(with: data) as? [String] ?? []
        }
        set {
            let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            return userDefaults.set(data, forKey: Keys.ethereumAddressesProtectedByUserPresence)
        }
    }

    private var analyticsCoordinator: AnalyticsCoordinator

    private var isSimulator: Bool {
        TARGET_OS_SIMULATOR != 0
    }

    //i.e if passcode is enabled. Face ID/Touch ID wouldn't work without passcode being enabled and we can't write to the keychain or generate a key in secure enclave when passcode is disabled
    //This original returns true for simulators (due to how simulators work), but on iOS 15 simulator (not on device and not on iOS 12.x and iOS 14 simulators), but writing the seed with user-presence enabled will fail silently and it breaks the app
    var isUserPresenceCheckPossible: Bool {
        if isSimulator {
            return false
        } else {
            let authContext = LAContext()
            return authContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        }
    }

    var hasWallets: Bool {
        return !wallets.isEmpty
    }

    var wallets: [Wallet] {
        let watchAddresses = self.watchAddresses.compactMap { AlphaWallet.Address(string: $0) }.map { Wallet(type: .watch($0)) }
        let addressesWithPrivateKeys = ethereumAddressesWithPrivateKeys.compactMap { AlphaWallet.Address(string: $0) }.map { Wallet(type: .real($0)) }
        let addressesWithSeed = ethereumAddressesWithSeed.compactMap { AlphaWallet.Address(string: $0) }.map { Wallet(type: .real($0)) }
        return addressesWithSeed + addressesWithPrivateKeys + watchAddresses
    }

    var subscribableWallets: Subscribable<Set<Wallet>> = .init(nil)

    var hasMigratedFromKeystoreFiles: Bool {
        return userDefaults.data(forKey: Keys.ethereumAddressesWithPrivateKeys) != nil
    }

    var recentlyUsedWallet: Wallet? {
        //Use `currentWallet` wherever possible instead of this getter to avoid optionals
        get {
            guard let address = keychain.get(Keys.recentlyUsedAddress) else {
                return nil
            }
            return wallets.filter {
                $0.address.sameContract(as: address)
            }.first
        }
        set {
            keychain.set(newValue?.address.eip55String ?? "", forKey: Keys.recentlyUsedAddress, withAccess: defaultKeychainAccessUserPresenceNotRequired)
        }
    }

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

    //TODO improve
    static var currentWallet: Wallet {
        //Better crash now instead of populating callers with optionals
        (try! EtherKeystore(analyticsCoordinator: NoOpAnalyticsService())).currentWallet
    }

    init(keychain: KeychainSwift = KeychainSwift(keyPrefix: Constants.keychainKeyPrefix), userDefaults: UserDefaults = .standard, analyticsCoordinator: AnalyticsCoordinator) throws {
        if !UIApplication.shared.isProtectedDataAvailable {
            throw EtherKeystoreError.protectionDisabled
        }
        self.keychain = keychain
        self.keychain.synchronizable = false
        self.analyticsCoordinator = analyticsCoordinator
        self.userDefaults = userDefaults
        super.init()

        subscribableWallets.value = Set<Wallet>(wallets)
    }

    // Async
    func createAccount(completion: @escaping (Result<AlphaWallet.Address, KeystoreError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let result = strongSelf.createAccount()
            OperationQueue.main.addOperation {
                completion(result)
            }
        }
    }

    func importWallet(type: ImportType, completion: @escaping (Result<Wallet, KeystoreError>) -> Void) {
        let results = importWallet(type: type)
        switch results {
        case .success(let wallet):
            //TODO not the best way to do this but let's see if there's a better way to inform the coordinator that a wallet has been imported to avoid it being prompted for back
            PromptBackupCoordinator(keystore: self, wallet: wallet, config: .init(), analyticsCoordinator: analyticsCoordinator).markWalletAsImported()
        case .failure:
            break
        }
        completion(results)
    }

    private func isAddressAlreadyInWalletsList(address: AlphaWallet.Address) -> Bool {
        return wallets.map({ $0.address }).contains { $0.sameContract(as: address) }
    }

    func importWallet(type: ImportType) -> Result<Wallet, KeystoreError> {
        switch type {
        case .keystore(let json, let password):
            guard let keystore = try? LegacyFileBasedKeystore(analyticsCoordinator: analyticsCoordinator) else {
                return .failure(.failedToExportPrivateKey)
            }
            let result = keystore.getPrivateKeyFromKeystoreFile(json: json, password: password)
            switch result {
            case .success(let privateKey):
                return importWallet(type: .privateKey(privateKey: privateKey))
            case .failure(let error):
                return .failure(error)
            }
        case .privateKey(let privateKey):
            let address = AlphaWallet.Address(fromPrivateKey: privateKey)
            guard !isAddressAlreadyInWalletsList(address: address) else {
                return .failure(.duplicateAccount)
            }
            if isUserPresenceCheckPossible {
                let isSuccessful = savePrivateKeyForNonHdWallet(privateKey, forAccount: address, withUserPresence: false)
                guard isSuccessful else { return .failure(.failedToCreateWallet) }
                let _ = savePrivateKeyForNonHdWallet(privateKey, forAccount: address, withUserPresence: true)
            } else {
                let isSuccessful = savePrivateKeyForNonHdWallet(privateKey, forAccount: address, withUserPresence: false)
                guard isSuccessful else { return .failure(.failedToCreateWallet) }
            }
            addToListOfEthereumAddressesWithPrivateKeys(address)
            return .success(Wallet(type: .real(address)))
        case .mnemonic(let mnemonic, _):
            let mnemonicString = mnemonic.joined(separator: " ")
            let mnemonicIsGood = doesSeedMatchWalletAddress(mnemonic: mnemonicString)
            guard mnemonicIsGood else { return .failure(.failedToCreateWallet) }
            guard let wallet = HDWallet(mnemonic: mnemonicString, passphrase: emptyPassphrase) else { return .failure(.failedToCreateWallet) }
            let privateKey = derivePrivateKeyOfAccount0(fromHdWallet: wallet)
            let address = AlphaWallet.Address(fromPrivateKey: privateKey)
            guard !isAddressAlreadyInWalletsList(address: address) else {
                return .failure(.duplicateAccount)
            }
            let seed = HDWallet.computeSeedWithChecksum(fromSeedPhrase: mnemonicString)
            if isUserPresenceCheckPossible {
                let isSuccessful = saveSeedForHdWallet(seed, forAccount: address, withUserPresence: false)
                guard isSuccessful else { return .failure(.failedToCreateWallet) }
                let _ = saveSeedForHdWallet(seed, forAccount: address, withUserPresence: true)
            } else {
                let isSuccessful = saveSeedForHdWallet(seed, forAccount: address, withUserPresence: false)
                guard isSuccessful else { return .failure(.failedToCreateWallet) }
            }
            addToListOfEthereumAddressesWithSeed(address)
            return .success(Wallet(type: .real(address)))
        case .watch(let address):
            guard !isAddressAlreadyInWalletsList(address: address) else {
                return .failure(.duplicateAccount)
            }
            watchAddresses = [watchAddresses, [address.eip55String]].flatMap {
                $0
            }

            notifyWalletUpdated()

            return .success(Wallet(type: .watch(address)))
        }
    }

    private func notifyWalletUpdated() {
        // NOTE: application crashes because adding a new wallet performed on background queue, we want to perform it on .main
        // using .addOperation we want to save operations order, hope it willn't crash. with DispatchQueue.main.async it crashes
        if Thread.isMainThread {
            subscribableWallets.value = Set<Wallet>(wallets)
        } else {
            OperationQueue.main.addOperation {
                self.subscribableWallets.value = Set<Wallet>(self.wallets)
            }
        }
    }

    private func addToListOfEthereumAddressesWithPrivateKeys(_ address: AlphaWallet.Address) {
        let updatedOwnedAddresses = Array(Set(ethereumAddressesWithPrivateKeys + [address.eip55String]))
        ethereumAddressesWithPrivateKeys = updatedOwnedAddresses

        notifyWalletUpdated()
    }

    private func addToListOfEthereumAddressesWithSeed(_ address: AlphaWallet.Address) {
        let updated = Array(Set(ethereumAddressesWithSeed + [address.eip55String]))
        ethereumAddressesWithSeed = updated

        notifyWalletUpdated()
    }

    private func addToListOfEthereumAddressesProtectedByUserPresence(_ address: AlphaWallet.Address) {
        let updated = Array(Set(ethereumAddressesProtectedByUserPresence + [address.eip55String]))
        ethereumAddressesProtectedByUserPresence = updated

        notifyWalletUpdated()
    }

    private func generateMnemonic() -> String {
        let seedPhraseCount: HDWallet.SeedPhraseCount = .word12
        repeat {
            if let newHdWallet = HDWallet(strength: seedPhraseCount.strength, passphrase: emptyPassphrase) {
                let mnemonicIsGood = doesSeedMatchWalletAddress(mnemonic: newHdWallet.mnemonic)
                if mnemonicIsGood {
                    return newHdWallet.mnemonic
                }
            } else {
                continue
            }
        } while true
    }

    func createAccount() -> Result<AlphaWallet.Address, KeystoreError> {
        let mnemonicString = generateMnemonic()
        let mnemonic = mnemonicString.split(separator: " ").map {
            String($0)
        }
        let result = importWallet(type: .mnemonic(words: mnemonic, password: emptyPassphrase))
        switch result {
        case .success(let wallet):
            return .success(wallet.address)
        case .failure:
            return .failure(.failedToCreateWallet)
        }
    }

    //Defensive check. Make sure mnemonic is OK and signs data correctly
    private func doesSeedMatchWalletAddress(mnemonic: String) -> Bool {
        guard let wallet = HDWallet(mnemonic: mnemonic, passphrase: emptyPassphrase) else { return false }
        guard wallet.mnemonic == mnemonic else { return false }
        let seed = HDWallet.computeSeedWithChecksum(fromSeedPhrase: mnemonic)
        guard let walletWhenImported = HDWallet(entropy: wallet.entropy, passphrase: emptyPassphrase) else { return false }
        //If seed phrase has a typo, the typo will be dropped and "abandon" added as the first word, deriving a different mnemonic silently. We don't want that to happen!
        guard walletWhenImported.mnemonic == mnemonic else { return false }
        let privateKey = derivePrivateKeyOfAccount0(fromHdWallet: walletWhenImported)
        let address = AlphaWallet.Address(fromPrivateKey: privateKey)
        let testData = "any data will do here"
        let hash = testData.data(using: .utf8)!.sha3(.keccak256)
        //Do not use EthereumSigner.vitaliklizeConstant because the ECRecover implementation doesn't include it
        guard let signature = try? EthereumSigner().sign(hash: hash, withPrivateKey: privateKey) else { return false }
        guard let recoveredAddress = Web3.Utils.hashECRecover(hash: hash, signature: signature) else { return false }
        //Make sure the wallet address (recoveredAddress) is what we think it is (address)
        return address.sameContract(as: recoveredAddress.address)
    }

    private func derivePrivateKeyOfAccount0(fromHdWallet wallet: HDWallet) -> Data {
        let firstAccountIndex = UInt32(0)
        let externalChangeConstant = UInt32(0)
        let addressIndex = UInt32(0)
        let privateKey = wallet.getDerivedKey(coin: .ethereum, account: firstAccountIndex, change: externalChangeConstant, address: addressIndex)
        return privateKey.data
    }

    func exportRawPrivateKeyForNonHdWalletForBackup(forAccount account: AlphaWallet.Address, newPassword: String, completion: @escaping (Result<String, KeystoreError>) -> Void) {
        let key: Data
        switch getPrivateKeyFromNonHdWallet(forAccount: account, prompt: R.string.localizable.keystoreAccessKeyNonHdBackup(), withUserPresence: isUserPresenceCheckPossible) {
        case .seed, .seedPhrase:
            //Not possible
            completion(.failure(.failedToExportPrivateKey))
            return
        case .key(let k):
            key = k
        case .userCancelled:
            completion(.failure(.userCancelled))
            return
        case .notFound, .otherFailure:
            completion(.failure(.accountMayNeedImportingAgainOrEnablePasscode))
            return
        }
        //Careful to not replace the if-let with a flatMap(). Because the value is a Result and it has flatMap() defined to "resolve" only when it's .success
        if let result = (try? LegacyFileBasedKeystore(analyticsCoordinator: analyticsCoordinator))?.export(privateKey: key, newPassword: newPassword) {
            completion(result)
        } else {
            completion(.failure(.failedToExportPrivateKey))
        }
    }

    func exportRawPrivateKeyFromHdWallet0thAddressForBackup(forAccount account: AlphaWallet.Address, newPassword: String, completion: @escaping (Result<String, KeystoreError>) -> Void) {
        let key: Data
        switch getPrivateKeyFromHdWallet0thAddress(forAccount: account, prompt: R.string.localizable.keystoreAccessKeyNonHdBackup(), withUserPresence: isUserPresenceCheckPossible) {
        case .seed, .seedPhrase:
            //Not possible
            completion(.failure(.failedToExportPrivateKey))
            return
        case .key(let k):
            key = k
        case .userCancelled:
            completion(.failure(.userCancelled))
            return
        case .notFound, .otherFailure:
            completion(.failure(.accountMayNeedImportingAgainOrEnablePasscode))
            return
        }
        //Careful to not replace the if-let with a flatMap(). Because the value is a Result and it has flatMap() defined to "resolve" only when it's .success
        if let result = (try? LegacyFileBasedKeystore(analyticsCoordinator: analyticsCoordinator))?.export(privateKey: key, newPassword: newPassword) {
            completion(result)
        } else {
            completion(.failure(.failedToExportPrivateKey))
        }
    }

    func exportSeedPhraseOfHdWallet(forAccount account: AlphaWallet.Address, context: LAContext, reason: KeystoreExportReason, completion: @escaping (Result<String, KeystoreError>) -> Void) {
        let seedPhrase = getSeedPhraseForHdWallet(forAccount: account, prompt: reason.prompt, context: context, withUserPresence: isUserPresenceCheckPossible)
        switch seedPhrase {
        case .seedPhrase(let seedPhrase):
            completion(.success(seedPhrase))
        case .seed, .key:
            completion(.failure(.failedToExportSeed))
        case .userCancelled:
            completion(.failure(.userCancelled))
        case .notFound, .otherFailure:
            completion(.failure(.failedToExportSeed))
        }
    }

    func verifySeedPhraseOfHdWallet(_ inputSeedPhrase: String, forAccount account: AlphaWallet.Address, context: LAContext, completion: @escaping (Result<Bool, KeystoreError>) -> Void) {
        switch getSeedPhraseForHdWallet(forAccount: account, prompt: R.string.localizable.keystoreAccessKeyHdVerify(), context: context, withUserPresence: isUserPresenceCheckPossible) {
        case .seedPhrase(let actualSeedPhrase):
            let matched = inputSeedPhrase.lowercased() == actualSeedPhrase.lowercased()
            completion(.success(matched))
        case .seed, .key:
            completion(.failure(.failedToExportSeed))
        case .userCancelled:
            completion(.failure(.userCancelled))
        case .notFound, .otherFailure:
            completion(.failure(.failedToExportSeed))
        }
    }

    @discardableResult func delete(wallet: Wallet) -> Result<Void, KeystoreError> {
        switch wallet.type {
        case .real(let account):
            //TODO not the best way to do this but let's see if there's a better way to inform the coordinator that a wallet has been deleted
            PromptBackupCoordinator(keystore: self, wallet: wallet, config: .init(), analyticsCoordinator: analyticsCoordinator).deleteWallet()

            removeAccountFromBookkeeping(account)
            deleteKeysAndSeedCipherTextFromKeychain(forAccount: account)
            deletePrivateKeysFromSecureEnclave(forAccount: account)
            //TODO: pass in Config instance instead
            Config().deleteWalletName(forAccount: account)
        case .watch(let address):
            removeAccountFromBookkeeping(address)
            //TODO: pass in Config instance instead
            Config().deleteWalletName(forAccount: address)
        }
        (try? LegacyFileBasedKeystore(analyticsCoordinator: analyticsCoordinator))?.delete(wallet: wallet)
        return .success(())
    }

    private func deletePrivateKeysFromSecureEnclave(forAccount account: AlphaWallet.Address) {
        let secureEnclave = SecureEnclave()
        secureEnclave.deletePrivateKeys(withName: encryptionKeyForPrivateKeyLabel(fromAccount: account, withUserPresence: true))
        secureEnclave.deletePrivateKeys(withName: encryptionKeyForPrivateKeyLabel(fromAccount: account, withUserPresence: false))
        secureEnclave.deletePrivateKeys(withName: encryptionKeyForSeedLabel(fromAccount: account, withUserPresence: true))
        secureEnclave.deletePrivateKeys(withName: encryptionKeyForSeedLabel(fromAccount: account, withUserPresence: false))
    }

    private func deleteKeysAndSeedCipherTextFromKeychain(forAccount account: AlphaWallet.Address) {
        keychain.delete("\(Keys.ethereumRawPrivateKeyUserPresenceNotRequiredPrefix)\(account.eip55String)")
        keychain.delete("\(Keys.ethereumRawPrivateKeyUserPresenceRequiredPrefix)\(account.eip55String)")
        keychain.delete("\(Keys.ethereumSeedUserPresenceNotRequiredPrefix)\(account.eip55String)")
        keychain.delete("\(Keys.ethereumSeedUserPresenceRequiredPrefix)\(account.eip55String)")
    }

    private func removeAccountFromBookkeeping(_ account: AlphaWallet.Address) {
        ethereumAddressesWithPrivateKeys = ethereumAddressesWithPrivateKeys.filter { $0 != account.eip55String }
        ethereumAddressesWithSeed = ethereumAddressesWithSeed.filter { $0 != account.eip55String }
        ethereumAddressesProtectedByUserPresence = ethereumAddressesProtectedByUserPresence.filter { $0 != account.eip55String }
        watchAddresses = watchAddresses.filter { $0 != account.eip55String }

        notifyWalletUpdated()
    }

    func isHdWallet(account: AlphaWallet.Address) -> Bool {
        return ethereumAddressesWithSeed.contains(account.eip55String)
    }

    func isHdWallet(wallet: Wallet) -> Bool {
        switch wallet.type {
        case .real(let account):
            return ethereumAddressesWithSeed.contains(account.eip55String)
        case .watch:
            return false
        }
    }

    func isKeystore(wallet: Wallet) -> Bool {
        switch wallet.type {
        case .real(let account):
            return ethereumAddressesWithPrivateKeys.contains(account.eip55String)
        case .watch:
            return false
        }
    }

    func isWatched(wallet: Wallet) -> Bool {
        switch wallet.type {
        case .real:
            return false
        case .watch(let address):
            return watchAddresses.contains(address.eip55String)
        }
    }

    func isProtectedByUserPresence(account: AlphaWallet.Address) -> Bool {
        return ethereumAddressesProtectedByUserPresence.contains(account.eip55String)
    }

    func signPersonalMessage(_ message: Data, for account: AlphaWallet.Address) -> Result<Data, KeystoreError> {
        let prefix = "\u{19}Ethereum Signed Message:\n\(message.count)".data(using: .utf8)!
        return signMessage(prefix + message, for: account)
    }

    func signHash(_ hash: Data, for account: AlphaWallet.Address) -> Result<Data, KeystoreError> {
        let key = getPrivateKeyForSigning(forAccount: account)
        switch key {
        case .seed, .seedPhrase:
            return .failure(.failedToExportPrivateKey)
        case .key(let key):
            do {
                var data = try EthereumSigner().sign(hash: hash, withPrivateKey: key)
                data[64] += EthereumSigner.vitaliklizeConstant
                return .success(data)
            } catch {
                return .failure(KeystoreError.failedToSignMessage)
            }
        case .userCancelled:
            return .failure(.userCancelled)
        case .notFound, .otherFailure:
            return .failure(.accountMayNeedImportingAgainOrEnablePasscode)
        }
    }

    func signEip712TypedData(_ data: EIP712TypedData, for account: AlphaWallet.Address) -> Result<Data, KeystoreError> {
        signHash(data.digest, for: account)
    }

    func signTypedMessage(_ datas: [EthTypedData], for account: AlphaWallet.Address) -> Result<Data, KeystoreError> {
        let schemas = datas.map { $0.schemaData }.reduce(Data(), { $0 + $1 }).sha3(.keccak256)
        let values = datas.map { $0.typedData }.reduce(Data(), { $0 + $1 }).sha3(.keccak256)
        let combined = (schemas + values).sha3(.keccak256)
        return signHash(combined, for: account)
    }

    func signMessage(_ message: Data, for account: AlphaWallet.Address) -> Result<Data, KeystoreError> {
        return signHash(message.sha3(.keccak256), for: account)
    }

    func signMessageBulk(_ data: [Data], for account: AlphaWallet.Address) -> Result<[Data], KeystoreError> {
        switch getPrivateKeyForSigning(forAccount: account) {
        case .seed, .seedPhrase:
            return .failure(.failedToExportPrivateKey)
        case .key(let key):
            do {
                var messageHashes = [Data]()
                for i in 0...data.count - 1 {
                    let hash = data[i].sha3(.keccak256)
                    messageHashes.append(hash)
                }
                var data = try EthereumSigner().signHashes(messageHashes, withPrivateKey: key)
                for i in 0...data.count - 1 {
                    data[i][64] += EthereumSigner.vitaliklizeConstant
                }
                return .success(data)
            } catch {
                return .failure(KeystoreError.failedToSignMessage)
            }
        case .userCancelled:
            return .failure(.userCancelled)
        case .notFound, .otherFailure:
            return .failure(.accountMayNeedImportingAgainOrEnablePasscode)
        }
    }

    func signMessageData(_ message: Data?, for account: AlphaWallet.Address) -> Result<Data, KeystoreError> {
        guard let hash = message?.sha3(.keccak256) else { return .failure(KeystoreError.failedToSignMessage) }
        switch getPrivateKeyForSigning(forAccount: account) {
        case .seed, .seedPhrase:
            return .failure(.failedToExportPrivateKey)
        case .key(let key):
            do {
                var data = try EthereumSigner().sign(hash: hash, withPrivateKey: key)
                data[64] += EthereumSigner.vitaliklizeConstant
                return .success(data)
            } catch {
                return .failure(KeystoreError.failedToSignMessage)
            }
        case .userCancelled:
            return .failure(.userCancelled)
        case .notFound, .otherFailure:
            return .failure(.accountMayNeedImportingAgainOrEnablePasscode)
        }
    }

    func signTransaction(_ transaction: UnsignedTransaction) -> Result<Data, KeystoreError> {
        let signer: Signer
        if transaction.server.chainID == 0 {
            signer = HomesteadSigner()
        } else {
            signer = EIP155Signer(server: transaction.server)
        }

        do {
            let hash = try signer.hash(transaction: transaction)
            switch getPrivateKeyForSigning(forAccount: transaction.account) {
            case .seed, .seedPhrase:
                return .failure(.failedToExportPrivateKey)
            case .key(let key):
                let signature = try EthereumSigner().sign(hash: hash, withPrivateKey: key)
                let (r, s, v) = signer.values(transaction: transaction, signature: signature)
                let values: [Any] = [
                    transaction.nonce,
                    transaction.gasPrice,
                    transaction.gasLimit,
                    transaction.to?.data ?? Data(),
                    transaction.value,
                    transaction.data,
                    v, r, s,
                ]
                //NOTE: avoid app crash, returns with return error, Happens when amount to send less then 0
                guard let data = RLP.encode(values) else {
                    return .failure(.failedToSignTransaction)
                }
                return .success(data)
            case .userCancelled:
                return .failure(.userCancelled)
            case .notFound, .otherFailure:
                return .failure(.accountMayNeedImportingAgainOrEnablePasscode)
            }
        } catch {
            return .failure(.failedToSignTransaction)
        }
    }

    private func getPrivateKeyForSigning(forAccount account: AlphaWallet.Address) -> WalletSeedOrKey {
        let prompt = R.string.localizable.keystoreAccessKeySign()
        if isHdWallet(account: account) {
            return getPrivateKeyFromHdWallet0thAddress(forAccount: account, prompt: prompt, withUserPresence: isUserPresenceCheckPossible)
        } else {
            return getPrivateKeyFromNonHdWallet(forAccount: account, prompt: prompt, withUserPresence: isUserPresenceCheckPossible)
        }
    }

    private func getPrivateKeyFromHdWallet0thAddress(forAccount account: AlphaWallet.Address, prompt: String, withUserPresence: Bool) -> WalletSeedOrKey {
        guard isHdWallet(account: account) else {
            assertImpossibleCodePath()
            return .otherFailure
        }
        let seedResult = getSeedForHdWallet(forAccount: account, prompt: prompt, context: createContext(), withUserPresence: withUserPresence)
        switch seedResult {
        case .seed(let seed):
            if let wallet = HDWallet(seed: seed, passphrase: emptyPassphrase) {
                let privateKey = derivePrivateKeyOfAccount0(fromHdWallet: wallet)
                return .key(privateKey)
            } else {
                return .otherFailure
            }
        case .userCancelled, .notFound, .otherFailure:
            return seedResult
        case .key, .seedPhrase:
            //Not possible
            return .otherFailure
        }
    }

    private func getPrivateKeyFromNonHdWallet(forAccount account: AlphaWallet.Address, prompt: String, withUserPresence: Bool, shouldWriteWithUserPresenceIfNotFound: Bool = true) -> WalletSeedOrKey {
        let prefix: String
        if withUserPresence {
            prefix = Keys.ethereumRawPrivateKeyUserPresenceRequiredPrefix
        } else {
            prefix = Keys.ethereumRawPrivateKeyUserPresenceNotRequiredPrefix
        }
        let context = createContext()
        let data = keychain.getData("\(prefix)\(account.eip55String)", prompt: prompt, withContext: context)
                .flatMap { decryptPrivateKey(fromCipherTextData: $0, forAccount: account, withUserPresence: withUserPresence, withContext: context) }

        //We copy the record that doesn't require user-presence make a new one which requires user-presence and read from that. We don't want to read the one without user-presence unless absolutely necessary (e.g user has disabled passcode)
        if data == nil && withUserPresence && shouldWriteWithUserPresenceIfNotFound && keychain.isDataNotFoundForLastAccess {
            switch getPrivateKeyFromNonHdWallet(forAccount: account, prompt: prompt, withUserPresence: false, shouldWriteWithUserPresenceIfNotFound: false) {
            case .seed, .seedPhrase:
                //Not possible
                break
            case .key(let keyWithoutUserPresence):
                let _ = savePrivateKeyForNonHdWallet(keyWithoutUserPresence, forAccount: account, withUserPresence: true)
            case .userCancelled, .notFound, .otherFailure:
                break
            }
            return getPrivateKeyFromNonHdWallet(forAccount: account, prompt: prompt, withUserPresence: true, shouldWriteWithUserPresenceIfNotFound: false)
        } else {
            if let data = data {
                return .key(data)
            } else {
                if keychain.hasUserCancelledLastAccess {
                    return .userCancelled
                } else if keychain.isDataNotFoundForLastAccess {
                    return .notFound
                } else {
                    return .otherFailure
                }
            }
        }
    }

    private func getSeedPhraseForHdWallet(forAccount account: AlphaWallet.Address, prompt: String, context: LAContext, withUserPresence: Bool) -> WalletSeedOrKey {
        let seedOrKey = getSeedForHdWallet(forAccount: account, prompt: prompt, context: context, withUserPresence: withUserPresence)
        switch seedOrKey {
        case .seed(let seed):
            if let wallet = HDWallet(seed: seed, passphrase: emptyPassphrase) {
                return .seedPhrase(wallet.mnemonic)
            } else {
                return .otherFailure
            }
        case .seedPhrase, .key:
            //Not possible
            return seedOrKey
        case .userCancelled, .notFound, .otherFailure:
            return seedOrKey
        }
    }

    private func getSeedForHdWallet(forAccount account: AlphaWallet.Address, prompt: String, context: LAContext, withUserPresence: Bool, shouldWriteWithUserPresenceIfNotFound: Bool = true) -> WalletSeedOrKey {
        let prefix: String
        if withUserPresence {
            prefix = Keys.ethereumSeedUserPresenceRequiredPrefix
        } else {
            prefix = Keys.ethereumSeedUserPresenceNotRequiredPrefix
        }
        let data = keychain.getData("\(prefix)\(account.eip55String)", prompt: prompt, withContext: context)
                .flatMap { decryptHdWalletSeed(fromCipherTextData: $0, forAccount: account, withUserPresence: withUserPresence, withContext: context) }
                .flatMap { String(data: $0, encoding: .utf8) }
        //We copy the record that doesn't require user-presence make a new one which requires user-presence and read from that. We don't want to read the one without user-presence unless absolutely necessary (e.g user has disabled passcode)
        if data == nil && withUserPresence && shouldWriteWithUserPresenceIfNotFound && keychain.isDataNotFoundForLastAccess {
            switch getSeedForHdWallet(forAccount: account, prompt: prompt, context: createContext(), withUserPresence: false, shouldWriteWithUserPresenceIfNotFound: false) {
            case .seed(let seedWithoutUserPresence):
                let _ = saveSeedForHdWallet(seedWithoutUserPresence, forAccount: account, withUserPresence: true)
            case .key, .seedPhrase:
                //Not possible
                break
            case .userCancelled, .notFound, .otherFailure:
                break
            }
            return getSeedForHdWallet(forAccount: account, prompt: prompt, context: createContext(), withUserPresence: true, shouldWriteWithUserPresenceIfNotFound: false)
        } else {
            if let data = data {
                return .seed(data)
            } else {
                if keychain.hasUserCancelledLastAccess {
                    return .userCancelled
                } else if keychain.isDataNotFoundForLastAccess {
                    return .notFound
                } else {
                    return .otherFailure
                }
            }
        }
    }

    private func savePrivateKeyForNonHdWallet(_ privateKey: Data, forAccount account: AlphaWallet.Address, withUserPresence: Bool) -> Bool {
        let context = createContext()
        guard let cipherTextData = encryptPrivateKey(privateKey, forAccount: account, withUserPresence: withUserPresence, withContext: context) else { return false }
        let access: KeychainSwiftAccessOptions
        let prefix: String
        if withUserPresence {
            access = defaultKeychainAccessUserPresenceRequired
            prefix = Keys.ethereumRawPrivateKeyUserPresenceRequiredPrefix
        } else {
            access = defaultKeychainAccessUserPresenceNotRequired
            prefix = Keys.ethereumRawPrivateKeyUserPresenceNotRequiredPrefix
        }
        return keychain.set(cipherTextData, forKey: "\(prefix)\(account.eip55String)", withAccess: access)
    }

    private func saveSeedForHdWallet(_ seed: String, forAccount account: AlphaWallet.Address, withUserPresence: Bool) -> Bool {
        let context = createContext()
        guard let cipherTextData = seed.data(using: .utf8).flatMap({ self.encryptHdWalletSeed($0, forAccount: account, withUserPresence: withUserPresence, withContext: context) }) else { return false }
        let access: KeychainSwiftAccessOptions
        let prefix: String
        if withUserPresence {
            access = defaultKeychainAccessUserPresenceRequired
            prefix = Keys.ethereumSeedUserPresenceRequiredPrefix
        } else {
            access = defaultKeychainAccessUserPresenceNotRequired
            prefix = Keys.ethereumSeedUserPresenceNotRequiredPrefix
        }
        return keychain.set(cipherTextData, forKey: "\(prefix)\(account.eip55String)", withAccess: access)
    }

    private func decryptHdWalletSeed(fromCipherTextData cipherTextData: Data, forAccount account: AlphaWallet.Address, withUserPresence: Bool, withContext context: LAContext) -> Data? {
        let secureEnclave = SecureEnclave(userPresenceRequired: withUserPresence)
        return try? secureEnclave.decrypt(cipherText: cipherTextData, withPrivateKeyFromLabel: encryptionKeyForSeedLabel(fromAccount: account, withUserPresence: withUserPresence), withContext: context)
    }

    private func decryptPrivateKey(fromCipherTextData cipherTextData: Data, forAccount account: AlphaWallet.Address, withUserPresence: Bool, withContext context: LAContext) -> Data? {
        let secureEnclave = SecureEnclave(userPresenceRequired: withUserPresence)
        return try? secureEnclave.decrypt(cipherText: cipherTextData, withPrivateKeyFromLabel: encryptionKeyForPrivateKeyLabel(fromAccount: account, withUserPresence: withUserPresence), withContext: context)
    }

    private func encryptHdWalletSeed(_ seed: Data, forAccount account: AlphaWallet.Address, withUserPresence: Bool, withContext context: LAContext) -> Data? {
        let secureEnclave = SecureEnclave(userPresenceRequired: withUserPresence)
        return try? secureEnclave.encrypt(plainTextData: seed, withPublicKeyFromLabel: encryptionKeyForSeedLabel(fromAccount: account, withUserPresence: withUserPresence), withContext: context)
    }

    private func encryptPrivateKey(_ key: Data, forAccount account: AlphaWallet.Address, withUserPresence: Bool, withContext context: LAContext) -> Data? {
        let secureEnclave = SecureEnclave(userPresenceRequired: withUserPresence)
        return try? secureEnclave.encrypt(plainTextData: key, withPublicKeyFromLabel: encryptionKeyForPrivateKeyLabel(fromAccount: account, withUserPresence: withUserPresence), withContext: context)
    }

    private func encryptionKeyForSeedLabel(fromAccount account: AlphaWallet.Address, withUserPresence: Bool) -> String {
        let prefix: String
        if withUserPresence {
            prefix = Keys.encryptionKeyForSeedUserPresenceRequiredPrefix
        } else {
            prefix = Keys.encryptionKeyForSeedUserPresenceNotRequiredPrefix
        }
        return "\(prefix)\(account.eip55String)"
    }

    private func encryptionKeyForPrivateKeyLabel(fromAccount account: AlphaWallet.Address, withUserPresence: Bool) -> String {
        let prefix: String
        if withUserPresence {
            prefix = Keys.encryptionKeyForPrivateKeyUserPresenceRequiredPrefix
        } else {
            prefix = Keys.encryptionKeyForPrivateKeyUserPresenceNotRequiredPrefix
        }
        return "\(prefix)\(account.eip55String)"
    }

    func elevateSecurity(forAccount account: AlphaWallet.Address) -> Bool {
        guard !isProtectedByUserPresence(account: account) else { return true }
        guard isUserPresenceCheckPossible else { return false }
        let prompt: String
        var isSuccessful: Bool
        if isHdWallet(account: account) {
            prompt = R.string.localizable.keystoreAccessKeyHdLock()
            let seed = getSeedForHdWallet(forAccount: account, prompt: prompt, context: createContext(), withUserPresence: false)
            switch seed {
            case .seed(let seed):
                isSuccessful = saveSeedForHdWallet(seed, forAccount: account, withUserPresence: true)
                if isSuccessful {
                    //Read it back, forcing iOS to check for user-presence
                    switch getSeedForHdWallet(forAccount: account, prompt: prompt, context: createContext(), withUserPresence: true) {
                    case .seed:
                        isSuccessful = true
                    case .key, .seedPhrase:
                        //Not possible
                        isSuccessful = false
                    case .userCancelled, .notFound, .otherFailure:
                        isSuccessful = false
                    }
                }
            case .key, .seedPhrase:
                //Not possible
                return false
            case .userCancelled:
                return false
            case .notFound, .otherFailure:
                return false
            }
        } else {
            prompt = R.string.localizable.keystoreAccessKeyNonHdLock()
            let keyStoredAsRawPrivateKey = getPrivateKeyFromNonHdWallet(forAccount: account, prompt: prompt, withUserPresence: false)
            switch keyStoredAsRawPrivateKey {
            case .seed, .seedPhrase:
                //Not possible
                return false
            case .key(let keyStoredAsRawPrivateKey):
                isSuccessful = savePrivateKeyForNonHdWallet(keyStoredAsRawPrivateKey, forAccount: account, withUserPresence: true)
                if isSuccessful {
                    //Read it back, forcing iOS to check for user-presence
                    switch getPrivateKeyFromNonHdWallet(forAccount: account, prompt: prompt, withUserPresence: true) {
                    case .seed, .seedPhrase:
                        //Not possible
                        isSuccessful = false
                    case .key:
                        isSuccessful = true
                    case .userCancelled, .notFound, .otherFailure:
                        isSuccessful = false
                    }
                }
            case .userCancelled:
                return false
            case .notFound, .otherFailure:
                return false
            }
        }
        if isSuccessful {
            addToListOfEthereumAddressesProtectedByUserPresence(account)
            let secureEnclave = SecureEnclave()
            if isHdWallet(account: account) {
                secureEnclave.deletePrivateKeys(withName: encryptionKeyForSeedLabel(fromAccount: account, withUserPresence: false))
                keychain.delete("\(Keys.ethereumSeedUserPresenceNotRequiredPrefix)\(account.eip55String)")
            } else {
                secureEnclave.deletePrivateKeys(withName: encryptionKeyForPrivateKeyLabel(fromAccount: account, withUserPresence: false))
                keychain.delete("\(Keys.ethereumRawPrivateKeyUserPresenceNotRequiredPrefix)\(account.eip55String)")
            }
        }
        return isSuccessful
    }

    private func createContext() -> LAContext {
        return .init()
    }
}
// swiftlint:enable type_body_length

extension KeychainSwift {
    var hasUserCancelledLastAccess: Bool {
        return lastResultCode == errSecUserCanceled
    }

    var isDataNotFoundForLastAccess: Bool {
        return lastResultCode == errSecItemNotFound
    }
}
