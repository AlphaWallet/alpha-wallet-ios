// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import LocalAuthentication
import BigInt
import KeychainSwift
import Result
import TrustWalletCore

enum EtherKeystoreError: LocalizedError {
    case protectionDisabled
}

///We use ECDSA keys, achieving symmetric encryption based on Diffie-Hellman to encrypt the HD wallet seed and raw private keys and store the ciphertext in the keychain
///
///The ECDSA key is stored in the secure enclave, not requiring user presence
///The ciphertext is stored in the keychain, not requiring user presence at first, but once user has backed up, requires user presence
open class EtherKeystore: Keystore {
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

    private let emptyPassphrase = ""
    private let keychain: KeychainSwift
    private let defaultKeychainAccessUserPresenceRequired: KeychainSwiftAccessOptions = .accessibleWhenUnlockedThisDeviceOnly(userPresenceRequired: true)
    private let defaultKeychainAccessUserPresenceNotRequired: KeychainSwiftAccessOptions = .accessibleWhenUnlockedThisDeviceOnly(userPresenceRequired: false)
    private let userDefaults: UserDefaults

    private var watchAddresses: [String] {
        set {
            let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            return userDefaults.set(data, forKey: Keys.watchAddresses)
        }
        get {
            guard let data = userDefaults.data(forKey: Keys.watchAddresses) else {
                return []
            }
            return NSKeyedUnarchiver.unarchiveObject(with: data) as? [String] ?? []
        }
    }

    private var ethereumAddressesWithPrivateKeys: [String] {
        set {
            let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            return userDefaults.set(data, forKey: Keys.ethereumAddressesWithPrivateKeys)
        }
        get {
            guard let data = userDefaults.data(forKey: Keys.ethereumAddressesWithPrivateKeys) else {
                return []
            }
            return NSKeyedUnarchiver.unarchiveObject(with: data) as? [String] ?? []
        }
    }

    private var ethereumAddressesWithSeed: [String] {
        set {
            let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            return userDefaults.set(data, forKey: Keys.ethereumAddressesWithSeed)
        }
        get {
            guard let data = userDefaults.data(forKey: Keys.ethereumAddressesWithSeed) else {
                return []
            }
            return NSKeyedUnarchiver.unarchiveObject(with: data) as? [String] ?? []
        }
    }

    private var ethereumAddressesProtectedByUserPresence: [String] {
        set {
            let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            return userDefaults.set(data, forKey: Keys.ethereumAddressesProtectedByUserPresence)
        }
        get {
            guard let data = userDefaults.data(forKey: Keys.ethereumAddressesProtectedByUserPresence) else {
                return []
            }
            return NSKeyedUnarchiver.unarchiveObject(with: data) as? [String] ?? []
        }
    }

    //i.e if passcode is enabled. Face ID/Touch ID wouldn't work without passcode being enabled and we can't write to the keychain or generate a key in secure enclave when passcode is disabled
    private var isUserPresenceCheckPossible: Bool {
        let authContext = LAContext()
        return authContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    var hasWallets: Bool {
        return !wallets.isEmpty
    }

    var wallets: [Wallet] {
        let watchAddresses = self.watchAddresses.compactMap { AlphaWallet.Address(string: $0) }.map { Wallet(type: .watch($0)) }
        let addressesWithPrivateKeys = ethereumAddressesWithPrivateKeys.compactMap { AlphaWallet.Address(string: $0) }.map { Wallet(type: .real(.init(address: $0))) }
        let addressesWithSeed = ethereumAddressesWithSeed.compactMap { AlphaWallet.Address(string: $0) }.map { Wallet(type: .real(.init(address: $0))) }
        return addressesWithSeed + addressesWithPrivateKeys + watchAddresses
    }

    var hasMigratedFromKeystoreFiles: Bool {
        return userDefaults.data(forKey: Keys.ethereumAddressesWithPrivateKeys) != nil
    }

    var recentlyUsedWallet: Wallet? {
        set {
            keychain.set(newValue?.address.eip55String ?? "", forKey: Keys.recentlyUsedAddress, withAccess: defaultKeychainAccessUserPresenceNotRequired)
        }
        get {
            guard let address = keychain.get(Keys.recentlyUsedAddress) else {
                return nil
            }
            return wallets.filter {
                $0.address.sameContract(as: address)
            }.first
        }
    }

    //TODO improve
    static var current: Wallet? {
        do {
            return try EtherKeystore().recentlyUsedWallet
        } catch {
            return .none
        }
    }

    public init(
            keychain: KeychainSwift = KeychainSwift(keyPrefix: Constants.keychainKeyPrefix),
            userDefaults: UserDefaults = UserDefaults.standard
    ) throws {
        if !UIApplication.shared.isProtectedDataAvailable {
            throw EtherKeystoreError.protectionDisabled
        }
        self.keychain = keychain
        self.keychain.synchronizable = false
        self.userDefaults = userDefaults
    }

    // Async
    func createAccount(completion: @escaping (Result<EthereumAccount, KeystoreError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let result = strongSelf.createAccount()
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    func importWallet(type: ImportType, completion: @escaping (Result<Wallet, KeystoreError>) -> Void) {
        let results = importWallet(type: type)
        switch results {
        case .success(let wallet):
            //TODO not the best way to do this but let's see if there's a better way to inform the coordinator that a wallet has been imported to avoid it being prompted for back
            PromptBackupCoordinator(keystore: self, wallet: wallet, config: .init()).markWalletAsImported()
        case .failure:
            break
        }
        completion(results)
    }

    func importWallet(type: ImportType) -> Result<Wallet, KeystoreError> {
        switch type {
        case .keystore(let json, let password):
            guard let keystore = try? LegacyFileBasedKeystore() else {
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
            let hasEthereumAddressAlready = wallets.map({ $0.address }).contains {
                $0.sameContract(as: address)
            }
            guard !hasEthereumAddressAlready else {
                return .failure(.duplicateAccount)
            }
            if isUserPresenceCheckPossible {
                let isSuccessful = savePrivateKeyForNonHdWallet(privateKey, forAccount: .init(address: address), withUserPresence: false)
                guard isSuccessful else { return .failure(.failedToCreateWallet) }
                let _ = savePrivateKeyForNonHdWallet(privateKey, forAccount: .init(address: address), withUserPresence: true)
            } else {
                let isSuccessful = savePrivateKeyForNonHdWallet(privateKey, forAccount: .init(address: address), withUserPresence: false)
                guard isSuccessful else { return .failure(.failedToCreateWallet) }
            }
            addToListOfEthereumAddressesWithPrivateKeys(address)
            return .success(Wallet(type: .real(.init(address: address))))
        case .mnemonic(let mnemonic, _):
            let mnemonicString = mnemonic.joined(separator: " ")
            let wallet = HDWallet(mnemonic: mnemonicString, passphrase: emptyPassphrase)
            let privateKey = derivePrivateKeyOfAccount0(fromHdWallet: wallet)
            let address = AlphaWallet.Address(fromPrivateKey: privateKey)
            let hasEthereumAddressAlready = wallets.map({ $0.address }).contains {
                $0.sameContract(as: address)
            }
            guard !hasEthereumAddressAlready else {
                return .failure(.duplicateAccount)
            }
            let seed = HDWallet.computeSeedWithChecksum(fromSeedPhrase: mnemonicString)
            if isUserPresenceCheckPossible {
                let isSuccessful = saveSeedForHdWallet(seed, forAccount: .init(address: address), withUserPresence: false)
                guard isSuccessful else { return .failure(.failedToCreateWallet) }
                let _ = saveSeedForHdWallet(seed, forAccount: .init(address: address), withUserPresence: true)
            } else {
                let isSuccessful = saveSeedForHdWallet(seed, forAccount: .init(address: address), withUserPresence: false)
                guard isSuccessful else { return .failure(.failedToCreateWallet) }
            }
            addToListOfEthereumAddressesWithSeed(address)
            return .success(Wallet(type: .real(.init(address: address))))
        case .watch(let address):
            guard !watchAddresses.contains(where: { address.sameContract(as: $0) }) else {
                return .failure(.duplicateAccount)
            }
            watchAddresses = [watchAddresses, [address.eip55String]].flatMap {
                $0
            }
            return .success(Wallet(type: .watch(address)))
        }
    }

    private func addToListOfEthereumAddressesWithPrivateKeys(_ address: AlphaWallet.Address) {
        let updatedOwnedAddresses = Array(Set(ethereumAddressesWithPrivateKeys + [address.eip55String]))
        ethereumAddressesWithPrivateKeys = updatedOwnedAddresses
    }

    private func addToListOfEthereumAddressesWithSeed(_ address: AlphaWallet.Address) {
        let updated = Array(Set(ethereumAddressesWithSeed + [address.eip55String]))
        ethereumAddressesWithSeed = updated
    }

    private func addToListOfEthereumAddressesProtectedByUserPresence(_ address: AlphaWallet.Address) {
        let updated = Array(Set(ethereumAddressesProtectedByUserPresence + [address.eip55String]))
        ethereumAddressesProtectedByUserPresence = updated
    }

    func createAccount() -> Result<EthereumAccount, KeystoreError> {
        let strength = Int32(128)
        let newHdWallet = HDWallet(strength: strength, passphrase: emptyPassphrase)
        let mnemonic = newHdWallet.mnemonic.split(separator: " ").map {
            String($0)
        }
        let result = importWallet(type: .mnemonic(words: mnemonic, password: emptyPassphrase))
        switch result {
        case .success(let wallet):
            return .success(.init(address: wallet.address))
        case .failure(let error):
            return .failure(.failedToCreateWallet)
        }
    }

    private func derivePrivateKeyOfAccount0(fromHdWallet wallet: HDWallet) -> Data {
        let firstAccountIndex = UInt32(0)
        let externalChangeConstant = UInt32(0)
        let addressIndex = UInt32(0)
        let privateKey = wallet.getKey(purpose: .bip44, coin: .ethereum, account: firstAccountIndex, change: externalChangeConstant, address: addressIndex)
        return privateKey.data
    }

    func exportRawPrivateKeyForNonHdWalletForBackup(forAccount account: EthereumAccount, newPassword: String, completion: @escaping (Result<String, KeystoreError>) -> Void) {
        guard let key = getPrivateKeyFromNonHdWallet(forAccount: account, prompt: R.string.localizable.keystoreAccessKeyNonHdBackup(), withUserPresence: isUserPresenceCheckPossible) else {
            return completion(.failure(.accountMayNeedImportingAgainOrEnablePasscode))
        }
        //Careful to not replace the if-let with a flatMap(). Because the value is a Result and it has flatMap() defined to "resolve" only when it's .success
        if let result = (try? LegacyFileBasedKeystore())?.export(privateKey: key, newPassword: newPassword) {
            completion(result)
        } else {
            completion(.failure(.failedToExportPrivateKey))
        }
    }

    func exportSeedPhraseOfHdWallet(forAccount account: EthereumAccount, reason: KeystoreExportReason, completion: @escaping (Result<String, KeystoreError>) -> Void) {
        if let seedPhrase = getSeedPhraseForHdWallet(forAccount: account, prompt: reason.prompt, withUserPresence: isUserPresenceCheckPossible) {
            completion(.success(seedPhrase))
        } else {
            completion(.failure(.failedToExportSeed))
        }
    }

    func verifySeedPhraseOfHdWallet(_ inputSeedPhrase: String, forAccount account: EthereumAccount, completion: @escaping (Result<Bool, KeystoreError>) -> Void) {
        if let actualSeedPhrase = getSeedPhraseForHdWallet(forAccount: account, prompt: R.string.localizable.keystoreAccessKeyHdVerify(), withUserPresence: isUserPresenceCheckPossible) {
            let matched = inputSeedPhrase.lowercased() == actualSeedPhrase.lowercased()
            completion(.success(matched))
        } else {
            completion(.failure(.failedToExportSeed))
        }
    }

    @discardableResult func delete(wallet: Wallet) -> Result<Void, KeystoreError> {
        switch wallet.type {
        case .real(let account):
            //TODO not the best way to do this but let's see if there's a better way to inform the coordinator that a wallet has been deleted
            PromptBackupCoordinator(keystore: self, wallet: wallet, config: .init()).deleteWallet()

            removeAccountFromBookkeeping(account)
            deleteKeysAndSeedCipherTextFromKeychain(forAccount: account)
            deletePrivateKeysFromSecureEnclave(forAccount: account)
        case .watch(let address):
            removeAccountFromBookkeeping(.init(address: address))
        }
        (try? LegacyFileBasedKeystore())?.delete(wallet: wallet)
        return .success(())
    }

    private func deletePrivateKeysFromSecureEnclave(forAccount account: EthereumAccount) {
        let secureEnclave = SecureEnclave()
        secureEnclave.deletePrivateKeys(withName: encryptionKeyForPrivateKeyLabel(fromAccount: account, withUserPresence: true))
        secureEnclave.deletePrivateKeys(withName: encryptionKeyForPrivateKeyLabel(fromAccount: account, withUserPresence: false))
        secureEnclave.deletePrivateKeys(withName: encryptionKeyForSeedLabel(fromAccount: account, withUserPresence: true))
        secureEnclave.deletePrivateKeys(withName: encryptionKeyForSeedLabel(fromAccount: account, withUserPresence: false))
    }

    private func deleteKeysAndSeedCipherTextFromKeychain(forAccount account: EthereumAccount) {
        keychain.delete("\(Keys.ethereumRawPrivateKeyUserPresenceNotRequiredPrefix)\(account.address.eip55String)")
        keychain.delete("\(Keys.ethereumRawPrivateKeyUserPresenceRequiredPrefix)\(account.address.eip55String)")
        keychain.delete("\(Keys.ethereumSeedUserPresenceNotRequiredPrefix)\(account.address.eip55String)")
        keychain.delete("\(Keys.ethereumSeedUserPresenceRequiredPrefix)\(account.address.eip55String)")
    }

    private func removeAccountFromBookkeeping(_ account: EthereumAccount) {
        ethereumAddressesWithPrivateKeys = ethereumAddressesWithPrivateKeys.filter { $0 != account.address.eip55String }
        ethereumAddressesWithSeed = ethereumAddressesWithSeed.filter { $0 != account.address.eip55String }
        ethereumAddressesProtectedByUserPresence = ethereumAddressesProtectedByUserPresence.filter { $0 != account.address.eip55String }
        watchAddresses = watchAddresses.filter { $0 != account.address.eip55String }
    }

    func delete(wallet: Wallet, completion: @escaping (Result<Void, KeystoreError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let result = strongSelf.delete(wallet: wallet)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    func isHdWallet(account: EthereumAccount) -> Bool {
        return ethereumAddressesWithSeed.contains(account.address.eip55String)
    }

    func isHdWallet(wallet: Wallet) -> Bool {
        switch wallet.type {
        case .real(let account):
            return ethereumAddressesWithSeed.contains(account.address.eip55String)
        case .watch:
            return false
        }
    }

    func isKeystore(wallet: Wallet) -> Bool {
        switch wallet.type {
        case .real(let account):
            return ethereumAddressesWithPrivateKeys.contains(account.address.eip55String)
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

    func isProtectedByUserPresence(account: EthereumAccount) -> Bool {
        return ethereumAddressesProtectedByUserPresence.contains(account.address.eip55String)
    }

    func signPersonalMessage(_ message: Data, for account: EthereumAccount) -> Result<Data, KeystoreError> {
        let prefix = "\u{19}Ethereum Signed Message:\n\(message.count)".data(using: .utf8)!
        return signMessage(prefix + message, for: account)
    }

    func signHash(_ hash: Data, for account: EthereumAccount) -> Result<Data, KeystoreError> {
        guard let key = getPrivateKeyForSigning(forAccount: account) else { return .failure(.accountMayNeedImportingAgainOrEnablePasscode) }
        do {
            var data = try EthereumSigner().sign(hash: hash, withPrivateKey: key)
            // TODO: Make it configurable, instead of overriding last byte.
            data[64] += 27
            return .success(data)
        } catch {
            return .failure(KeystoreError.failedToSignMessage)
        }
    }

    func signTypedMessage(_ datas: [EthTypedData], for account: EthereumAccount) -> Result<Data, KeystoreError> {
        let schemas = datas.map { $0.schemaData }.reduce(Data(), { $0 + $1 }).sha3(.keccak256)
        let values = datas.map { $0.typedData }.reduce(Data(), { $0 + $1 }).sha3(.keccak256)
        let combined = (schemas + values).sha3(.keccak256)
        return signHash(combined, for: account)
    }

    func signMessage(_ message: Data, for account: EthereumAccount) -> Result<Data, KeystoreError> {
        return signHash(message.sha3(.keccak256), for: account)
    }

    func signMessageBulk(_ data: [Data], for account: EthereumAccount) -> Result<[Data], KeystoreError> {
        guard let key = getPrivateKeyForSigning(forAccount: account) else { return .failure(.accountMayNeedImportingAgainOrEnablePasscode) }

        do {
            var messageHashes = [Data]()
            for i in 0...data.count - 1 {
                let hash = data[i].sha3(.keccak256)
                messageHashes.append(hash)
            }
            var data = try EthereumSigner().signHashes(messageHashes, withPrivateKey: key)
            // TODO: Make it configurable, instead of overriding last byte.
            for i in 0...data.count - 1 {
                data[i][64] += 27
            }
            return .success(data)
        } catch {
            return .failure(KeystoreError.failedToSignMessage)
        }
    }

    func signMessageData(_ message: Data?, for account: EthereumAccount) -> Result<Data, KeystoreError> {
        guard let hash = message?.sha3(.keccak256) else { return .failure(KeystoreError.failedToSignMessage) }
        guard let key = getPrivateKeyForSigning(forAccount: account) else { return .failure(.accountMayNeedImportingAgainOrEnablePasscode) }
        do {
            var data = try EthereumSigner().sign(hash: hash, withPrivateKey: key)
            data[64] += 27
            return .success(data)
        } catch {
            return .failure(KeystoreError.failedToSignMessage)
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
            let hash = signer.hash(transaction: transaction)
            guard let key = getPrivateKeyForSigning(forAccount: transaction.account) else { return .failure(.accountMayNeedImportingAgainOrEnablePasscode) }
            let signature = try EthereumSigner().sign(hash: hash, withPrivateKey: key)
            let (r, s, v) = signer.values(transaction: transaction, signature: signature)
            let data = RLP.encode([
                transaction.nonce,
                transaction.gasPrice,
                transaction.gasLimit,
                transaction.to?.data ?? Data(),
                transaction.value,
                transaction.data,
                v, r, s,
            ])!
            return .success(data)
        } catch {
            return .failure(.failedToSignTransaction)
        }
    }

    //TODO should and can we check if the keychain has that entry without prompting for user-presence?
    func getAccount(for address: AlphaWallet.Address) -> EthereumAccount? {
        return .init(address: address)
    }

    private func getPrivateKeyForSigning(forAccount account: EthereumAccount) -> Data? {
        let prompt = R.string.localizable.keystoreAccessKeySign()
        if isHdWallet(account: account) {
            guard let seed = getSeedForHdWallet(forAccount: account, prompt: prompt, withUserPresence: isUserPresenceCheckPossible) else { return nil }
            let wallet = HDWallet(seed: seed, passphrase: emptyPassphrase)
            let privateKey = derivePrivateKeyOfAccount0(fromHdWallet: wallet)
            return privateKey
        } else {
            return getPrivateKeyFromNonHdWallet(forAccount: account, prompt: prompt, withUserPresence: isUserPresenceCheckPossible)
        }
    }

    private func getPrivateKeyFromNonHdWallet(forAccount account: EthereumAccount, prompt: String, withUserPresence: Bool, shouldWriteWithUserPresenceIfNotFound: Bool = true) -> Data? {
        let prefix: String
        if withUserPresence {
            prefix = Keys.ethereumRawPrivateKeyUserPresenceRequiredPrefix
        } else {
            prefix = Keys.ethereumRawPrivateKeyUserPresenceNotRequiredPrefix
        }
        let data = keychain.getData("\(prefix)\(account.address.eip55String)", prompt: prompt)
                .flatMap { decryptPrivateKey(fromCipherTextData: $0, forAccount: account, withUserPresence: withUserPresence) }
        
        //We copy the record that doesn't require user-presence make a new one which requires user-presence and read from that. We don't want to read the one without user-presence unless absolutely necessary (e.g user has disabled passcode)
        if data == nil && withUserPresence && shouldWriteWithUserPresenceIfNotFound && keychain.lastResultCode == errSecItemNotFound {
            if let keyWithoutUserPresence = getPrivateKeyFromNonHdWallet(forAccount: account, prompt: prompt, withUserPresence: false, shouldWriteWithUserPresenceIfNotFound: false) {
                savePrivateKeyForNonHdWallet(keyWithoutUserPresence, forAccount: account, withUserPresence: true)
            }
            return getPrivateKeyFromNonHdWallet(forAccount: account, prompt: prompt, withUserPresence: true, shouldWriteWithUserPresenceIfNotFound: false)
        } else {
            return data
        }
    }

    private func getSeedPhraseForHdWallet(forAccount account: EthereumAccount, prompt: String, withUserPresence: Bool) -> String? {
        return getSeedForHdWallet(forAccount: account, prompt: prompt, withUserPresence: withUserPresence)
                .flatMap { HDWallet(seed: $0, passphrase: emptyPassphrase) }
                .flatMap { $0.mnemonic }
    }

    private func getSeedForHdWallet(forAccount account: EthereumAccount, prompt: String, withUserPresence: Bool, shouldWriteWithUserPresenceIfNotFound: Bool = true) -> String? {
        let prefix: String
        if withUserPresence {
            prefix = Keys.ethereumSeedUserPresenceRequiredPrefix
        } else {
            prefix = Keys.ethereumSeedUserPresenceNotRequiredPrefix
        }
        let data = keychain.getData("\(prefix)\(account.address.eip55String)", prompt: prompt)
                .flatMap { decryptHdWalletSeed(fromCipherTextData: $0, forAccount: account, withUserPresence: withUserPresence) }
                .flatMap { String(data: $0, encoding: .utf8) }
        //We copy the record that doesn't require user-presence make a new one which requires user-presence and read from that. We don't want to read the one without user-presence unless absolutely necessary (e.g user has disabled passcode)
        if data == nil && withUserPresence && shouldWriteWithUserPresenceIfNotFound && keychain.lastResultCode == errSecItemNotFound {
            if let seedWithoutUserPresence = getSeedForHdWallet(forAccount: account, prompt: prompt, withUserPresence: false, shouldWriteWithUserPresenceIfNotFound: false) {
                saveSeedForHdWallet(seedWithoutUserPresence, forAccount: account, withUserPresence: true)
            }
            return getSeedForHdWallet(forAccount: account, prompt: prompt, withUserPresence: true, shouldWriteWithUserPresenceIfNotFound: false)
        } else {
            return data
        }
    }

    private func savePrivateKeyForNonHdWallet(_ privateKey: Data, forAccount account: EthereumAccount, withUserPresence: Bool) -> Bool {
        guard let cipherTextData = encryptPrivateKey(privateKey, forAccount: account, withUserPresence: withUserPresence) else { return false }
        let access: KeychainSwiftAccessOptions
        let prefix: String
        if withUserPresence {
            access = defaultKeychainAccessUserPresenceRequired
            prefix = Keys.ethereumRawPrivateKeyUserPresenceRequiredPrefix
        } else {
            access = defaultKeychainAccessUserPresenceNotRequired
            prefix = Keys.ethereumRawPrivateKeyUserPresenceNotRequiredPrefix
        }
        return keychain.set(cipherTextData, forKey: "\(prefix)\(account.address.eip55String)", withAccess: access)
    }

    private func saveSeedForHdWallet(_ seed: String, forAccount account: EthereumAccount, withUserPresence: Bool) -> Bool {
        guard let cipherTextData = seed.data(using: .utf8).flatMap({ self.encryptHdWalletSeed($0, forAccount: account, withUserPresence: withUserPresence) }) else { return false }
        let access: KeychainSwiftAccessOptions
        let prefix: String
        if withUserPresence {
            access = defaultKeychainAccessUserPresenceRequired
            prefix = Keys.ethereumSeedUserPresenceRequiredPrefix
        } else {
            access = defaultKeychainAccessUserPresenceNotRequired
            prefix = Keys.ethereumSeedUserPresenceNotRequiredPrefix
        }
        return keychain.set(cipherTextData, forKey: "\(prefix)\(account.address.eip55String)", withAccess: access)
    }

    private func decryptHdWalletSeed(fromCipherTextData cipherTextData: Data, forAccount account: EthereumAccount, withUserPresence: Bool) -> Data? {
        let secureEnclave = SecureEnclave()
        return try? secureEnclave.decrypt(cipherText: cipherTextData, withPrivateKeyFromLabel: encryptionKeyForSeedLabel(fromAccount: account, withUserPresence: withUserPresence))
    }

    private func decryptPrivateKey(fromCipherTextData cipherTextData: Data, forAccount account: EthereumAccount, withUserPresence: Bool) -> Data? {
        let secureEnclave = SecureEnclave()
        return try? secureEnclave.decrypt(cipherText: cipherTextData, withPrivateKeyFromLabel: encryptionKeyForPrivateKeyLabel(fromAccount: account, withUserPresence: withUserPresence))
    }

    private func encryptHdWalletSeed(_ seed: Data, forAccount account: EthereumAccount, withUserPresence: Bool) -> Data? {
        let secureEnclave = SecureEnclave()
        return try? secureEnclave.encrypt(plainTextData: seed, withPublicKeyFromLabel: encryptionKeyForSeedLabel(fromAccount: account, withUserPresence: withUserPresence))
    }

    private func encryptPrivateKey(_ key: Data, forAccount account: EthereumAccount, withUserPresence: Bool) -> Data? {
        let secureEnclave = SecureEnclave()
        return try? secureEnclave.encrypt(plainTextData: key, withPublicKeyFromLabel: encryptionKeyForPrivateKeyLabel(fromAccount: account, withUserPresence: withUserPresence))
    }

    private func encryptionKeyForSeedLabel(fromAccount account: EthereumAccount, withUserPresence: Bool) -> String {
        let prefix: String
        if withUserPresence {
            prefix = Keys.encryptionKeyForSeedUserPresenceRequiredPrefix
        } else {
            prefix = Keys.encryptionKeyForSeedUserPresenceNotRequiredPrefix
        }
        return "\(prefix)\(account.address.eip55String)"
    }

    private func encryptionKeyForPrivateKeyLabel(fromAccount account: EthereumAccount, withUserPresence: Bool) -> String {
        let prefix: String
        if withUserPresence {
            prefix = Keys.encryptionKeyForPrivateKeyUserPresenceRequiredPrefix
        } else {
            prefix = Keys.encryptionKeyForPrivateKeyUserPresenceNotRequiredPrefix
        }
        return "\(prefix)\(account.address.eip55String)"
    }

    func elevateSecurity(forAccount account: EthereumAccount) -> Bool {
        guard !isProtectedByUserPresence(account: account) else { return true }
        guard isUserPresenceCheckPossible else { return false }
        //Text isn't shown since we don't have user presence set yet. Don't need to localize
        let prompt = "To elevate security for your wallet key"
        let isSuccessful: Bool
        if isHdWallet(account: account) {
            guard let seed = getSeedForHdWallet(forAccount: account, prompt: prompt, withUserPresence: false) else { return false }
            isSuccessful = saveSeedForHdWallet(seed, forAccount: account, withUserPresence: true)
        } else {
            guard let keyStoredAsRawPrivateKey = getPrivateKeyFromNonHdWallet(forAccount: account, prompt: prompt, withUserPresence: false) else { return false }
            isSuccessful = savePrivateKeyForNonHdWallet(keyStoredAsRawPrivateKey, forAccount: account, withUserPresence: true)
        }
        if isSuccessful {
            addToListOfEthereumAddressesProtectedByUserPresence(account.address)
            let secureEnclave = SecureEnclave()
            if isHdWallet(account: account) {
                secureEnclave.deletePrivateKeys(withName: encryptionKeyForSeedLabel(fromAccount: account, withUserPresence: false))
                keychain.delete("\(Keys.ethereumSeedUserPresenceNotRequiredPrefix)\(account.address.eip55String)")
            } else {
                secureEnclave.deletePrivateKeys(withName: encryptionKeyForPrivateKeyLabel(fromAccount: account, withUserPresence: false))
                keychain.delete("\(Keys.ethereumRawPrivateKeyUserPresenceNotRequiredPrefix)\(account.address.eip55String)")
            }
        }
        return isSuccessful
    }
}
