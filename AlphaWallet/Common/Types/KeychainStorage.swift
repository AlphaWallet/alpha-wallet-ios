//
//  KeychainStorage.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.09.2022.
//

import Foundation
import KeychainSwift
import SAMKeychain
import AlphaWalletFoundation
import LocalAuthentication

final class KeychainStorage: SecuredStorage, SecuredPasswordStorage {
    private let keychain: KeychainSwift

    init(keyPrefix: String = Constants.keychainKeyPrefix) throws {
        let keychain = KeychainSwift(keyPrefix: Constants.keychainKeyPrefix)
        keychain.synchronizable = false

        self.keychain = keychain
        if !UIApplication.shared.isProtectedDataAvailable {
            throw EtherKeystoreError.protectionDisabled
        }
    }
    
    var hasUserCancelledLastAccess: Bool {
        return keychain.lastResultCode == errSecUserCanceled
    }

    var isDataNotFoundForLastAccess: Bool {
        return keychain.lastResultCode == errSecItemNotFound
    }

    func set(_ value: String, forKey key: String, withAccess access: AccessOptions?) -> Bool {
        return keychain.set(value, forKey: key, withAccess: access?.asKeychainOptions)
    }

    func set(_ value: Data, forKey key: String, withAccess access: AccessOptions?) -> Bool {
        return keychain.set(value, forKey: key, withAccess: access?.asKeychainOptions)
    }

    func get(_ key: String, prompt: String?, withContext context: LAContext?) -> String? {
        return keychain.get(key, prompt: prompt, withContext: context)
    }

    func getData(_ key: String, prompt: String?, withContext context: LAContext?) -> Data? {
        return keychain.getData(key, prompt: prompt, withContext: context)
    }

    func delete(_ key: String) -> Bool {
        return keychain.delete(key)
    }

    func password(forService service: String, account: String) -> String? {
        return SAMKeychain.password(forService: service, account: account)
    }

    func setPasword(_ pasword: String, forService service: String, account: String) {
        SAMKeychain.setPassword(pasword, forService: service, account: account)
    }

    func deletePasword(forService service: String, account: String) {
        SAMKeychain.deletePassword(forService: service, account: account)
    }
}

fileprivate extension AccessOptions {
    var asKeychainOptions: KeychainSwiftAccessOptions {
        switch self {
        case .accessibleWhenUnlocked:
            return .accessibleWhenUnlocked
        case .accessibleWhenUnlockedThisDeviceOnly(let userPresenceRequired):
            return .accessibleWhenUnlockedThisDeviceOnly(userPresenceRequired: userPresenceRequired)
        case .accessibleAfterFirstUnlock:
            return .accessibleAfterFirstUnlock
        case .accessibleAfterFirstUnlockThisDeviceOnly:
            return .accessibleAfterFirstUnlockThisDeviceOnly
        case .accessibleAlways:
            return .accessibleAlways
        case .accessibleWhenPasscodeSetThisDeviceOnly:
            return .accessibleWhenPasscodeSetThisDeviceOnly
        case .accessibleAlwaysThisDeviceOnly:
            return .accessibleAlwaysThisDeviceOnly
        }
    }
}
