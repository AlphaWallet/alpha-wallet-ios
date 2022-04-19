import Foundation

public class KeyManagementService {
    enum Error: Swift.Error {
        case keyNotFound
    }
    
    private var keychain: KeychainStorageProtocol
    
    public init(serviceIdentifier: String) {
        self.keychain =  KeychainStorage(serviceIdentifier:  serviceIdentifier)
    }
    
    init(keychain: KeychainStorageProtocol) {
        self.keychain = keychain
    }
    
    public func createX25519KeyPair() throws -> AgreementPublicKey {
        let privateKey = AgreementPrivateKey()
        try setPrivateKey(privateKey)
        return privateKey.publicKey
    }
    
    public func setPrivateKey(_ privateKey: AgreementPrivateKey) throws {
        try keychain.add(privateKey, forKey: privateKey.publicKey.hexRepresentation)
    }
    
    public func setAgreementSecret(_ agreementSecret: AgreementSecret, topic: String) throws {
        try keychain.add(agreementSecret, forKey: topic)
    }
    
    public func getPrivateKey(for publicKey: AgreementPublicKey) throws -> AgreementPrivateKey? {
        do {
            return try keychain.read(key: publicKey.hexRepresentation) as AgreementPrivateKey
        } catch let error where (error as? KeychainError)?.status == errSecItemNotFound {
            return nil
        } catch {
            throw error
        }
    }
    
    public func getAgreementSecret(for topic: String) throws -> AgreementSecret? {
        do {
            return try keychain.read(key: topic) as AgreementSecret
        } catch let error where (error as? KeychainError)?.status == errSecItemNotFound {
            return nil
        } catch {
            throw error
        }
    }
    
    public func deletePrivateKey(for publicKey: String) {
        do {
            try keychain.delete(key: publicKey)
        } catch {
            print("Error deleting private key: \(error)")
        }
    }
    
    public func deleteAgreementSecret(for topic: String) {
        do {
            try keychain.delete(key: topic)
        } catch {
            print("Error deleting agreement key: \(error)")
        }
    }
    
    public func performKeyAgreement(selfPublicKey: AgreementPublicKey, peerPublicKey hexRepresentation: String) throws -> AgreementSecret {
        guard let privateKey = try getPrivateKey(for: selfPublicKey) else {
            print("Key Agreement Error: Private key not found for public key: \(selfPublicKey.hexRepresentation)")
            throw KeyManagementService.Error.keyNotFound
        }
        return try KeyManagementService.generateAgreementSecret(from: privateKey, peerPublicKey: hexRepresentation)
    }
    
    static func generateAgreementSecret(from privateKey: AgreementPrivateKey, peerPublicKey hexRepresentation: String) throws -> AgreementSecret {
        let peerPublicKey = try AgreementPublicKey(rawRepresentation: Data(hex: hexRepresentation))
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)
        let rawSecret = sharedSecret.withUnsafeBytes { return Data(Array($0)) }
        return AgreementSecret(sharedSecret: rawSecret, publicKey: privateKey.publicKey)
    }
}
