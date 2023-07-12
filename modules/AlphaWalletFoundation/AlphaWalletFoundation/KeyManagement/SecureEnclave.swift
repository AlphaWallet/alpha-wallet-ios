// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import LocalAuthentication
import Security

class SecureEnclave {
    enum Error: LocalizedError {
        case keyAlreadyExists(name: String)
        case cannotAccessPrivateKey(osStatus: OSStatus)
        case cannotAccessPublicKey
        case encryptionNotSupported(algorithm: SecKeyAlgorithm)
        case decryptionNotSupported(algorithm: SecKeyAlgorithm)
        case cannotEncrypt
        case cannotDecrypt
        case unexpected(description: String)

        var errorDescription: String? {
            switch self {
            case .keyAlreadyExists(let name):
                return "Encryption key already exist for: \(name)"
            case .cannotAccessPrivateKey(let osStatus):
                return "Cannot access private key because: \(osStatus)"
            case .cannotAccessPublicKey:
                return "Cannot access public key"
            case .encryptionNotSupported(let algorithm):
                return "Encryption not supported: \(algorithm)"
            case .decryptionNotSupported(let algorithm):
                return "Decryption not supported: \(algorithm)"
            case .cannotEncrypt:
                return "Cannot encrypt"
            case .cannotDecrypt:
                return "Cannot decrypt"
            case .unexpected(let description):
                return description
            }
        }
    }

    private let requiresBiometry = true
    private let numberOfBitsInKey = 256
    private let algorithm = SecKeyAlgorithm.eciesEncryptionCofactorVariableIVX963SHA256AESGCM
    private let userPresenceRequired: Bool

    private var isSimulator: Bool {
        return TARGET_OS_SIMULATOR != 0
    }

    init(userPresenceRequired: Bool = false) {
        self.userPresenceRequired = userPresenceRequired
    }

    private func getPrivateKey(withName name: String, withContext context: LAContext) throws -> SecKey {
        let params: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: tagData(fromName: name),
            kSecReturnRef as String: true,
            kSecUseAuthenticationContext as String: context,
        ]

        var raw: CFTypeRef?
        let status = SecItemCopyMatching(params as CFDictionary, &raw)
        guard status == errSecSuccess, let result = raw else {
            throw Error.cannotAccessPrivateKey(osStatus: status)
        }
        return result as! SecKey
    }

    private func getPrivateKeyCount(withName name: String) -> Int {
        let params: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: tagData(fromName: name),
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var raw: CFTypeRef?
        let status = SecItemCopyMatching(params as CFDictionary, &raw)
        if status == errSecSuccess, let all = raw as? [SecKey] {
            return all.count
        } else {
            return 0
        }
    }

    private func encrypt(plainTextData: Data, withPublicKey publicKey: SecKey) throws -> Data {
        guard SecKeyIsAlgorithmSupported(publicKey, .encrypt, algorithm) else {
            throw Error.encryptionNotSupported(algorithm: algorithm)
        }
        var error: Unmanaged<CFError>?
        guard let cipherTextData = SecKeyCreateEncryptedData(publicKey, algorithm, plainTextData as CFData, &error) as Data? else {
            throw Error.cannotEncrypt
        }
        return cipherTextData
    }

    private func decrypt(cipherText: Data, privateKey: SecKey) throws -> Data {
        guard SecKeyIsAlgorithmSupported(privateKey, .decrypt, algorithm) else {
            throw Error.decryptionNotSupported(algorithm: algorithm)
        }

        var error: Unmanaged<CFError>?
        guard let plainTextData = SecKeyCreateDecryptedData(privateKey, algorithm, cipherText as CFData, &error) as Data? else {
            throw Error.cannotDecrypt
        }
        return plainTextData
    }

    private func tagData(fromName name: String) -> Data {
        return Data(name.utf8)
    }

    private func createPrivateKey(withName name: String) throws -> SecKey {
        let count = getPrivateKeyCount(withName: name)
        // swiftlint:disable empty_count
        guard count == 0 else { throw Error.keyAlreadyExists(name: name) }
        // swiftlint:enable empty_count

        let flags: SecAccessControlCreateFlags
        if requiresBiometry && userPresenceRequired {
            flags = [.privateKeyUsage, .userPresence]
        } else {
            flags = .privateKeyUsage
        }
        guard let access = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, flags, nil) else { throw Error.unexpected(description: "Unable to create flags to create private key") }
        var attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: numberOfBitsInKey,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tagData(fromName: name),
                kSecAttrAccessControl as String: access
            ]
        ]
        if isSimulator {
            //do nothing
        } else {
            attributes[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
        }

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Swift.Error
        }

        return privateKey
    }

    // MARK: Public interface

    func encrypt(plainTextData: Data, withPublicKeyFromLabel name: String, withContext context: LAContext) throws -> Data {
        let privateKey: SecKey
        do {
            privateKey = try getPrivateKey(withName: name, withContext: context)
        } catch {
            privateKey = try createPrivateKey(withName: name)
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else { throw Error.cannotAccessPublicKey }

        return try encrypt(plainTextData: plainTextData, withPublicKey: publicKey)
    }

    func decrypt(cipherText: Data, withPrivateKeyFromLabel name: String, withContext context: LAContext) throws -> Data {
        let privateKey = try getPrivateKey(withName: name, withContext: context)
        return try decrypt(cipherText: cipherText, privateKey: privateKey)
    }

    func deletePrivateKeys(withName name: String) {
        let params: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: tagData(fromName: name)
        ]
        let _ = SecItemDelete(params as CFDictionary)
    }
}
