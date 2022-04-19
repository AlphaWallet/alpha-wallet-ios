import Foundation
import WalletConnectUtils


public class Serializer {
    enum Error: String, Swift.Error {
        case messageToShort = "Error: message is too short"
    }
    private let kms: KeyManagementService
    private let codec: Codec
    
    init(kms: KeyManagementService, codec: Codec = AES_256_CBC_HMAC_SHA256_Codec()) {
        self.kms = kms
        self.codec = codec
    }
    
    public init(kms: KeyManagementService) {
        self.kms = kms
        self.codec = AES_256_CBC_HMAC_SHA256_Codec()
    }
    
    /// Encrypts and serializes an object into (iv + publicKey + mac + cipherText) formatted sting
    /// - Parameters:
    ///   - topic: Topic that is associated with a symetric key for encrypting particular codable object
    ///   - message: Message to encrypt and serialize
    /// - Returns: Serialized String
    public func serialize(topic: String, encodable: Encodable) throws -> String {
        let messageJson = try encodable.json()
        var message: String
        if let agreementKeys = try? kms.getAgreementSecret(for: topic) {
            message = try encrypt(json: messageJson, agreementKeys: agreementKeys)
        } else {
            message = messageJson.toHexEncodedString(uppercase: false)
        }
        return message
    }
    
    /// Deserializes and decrypts an object from (iv + publicKey + mac + cipherText) formatted sting
    /// - Parameters:
    ///   - topic: Topic that is associated with a symetric key for decrypting particular codable object
    ///   - message: Message to deserialize and decrypt
    /// - Returns: Deserialized object
    public func tryDeserialize<T: Codable>(topic: String, message: String) -> T? {
        do {
            let deserializedCodable: T
            if let agreementKeys = try? kms.getAgreementSecret(for: topic) {
                deserializedCodable = try deserialize(message: message, symmetricKey: agreementKeys.sharedSecret)
            } else {
                let jsonData = Data(hex: message)
                deserializedCodable = try JSONDecoder().decode(T.self, from: jsonData)
            }
            return deserializedCodable
        } catch {
            return nil
        }
    }
    
    func deserialize<T: Codable>(message: String, symmetricKey: Data) throws -> T {
        let decryptedData = try decrypt(message: message, symmetricKey: symmetricKey)
        return try JSONDecoder().decode(T.self, from: decryptedData)
    }
    
    func encrypt(json: String, agreementKeys: AgreementSecret) throws -> String {
        let payload = try codec.encode(plainText: json, agreementKeys: agreementKeys)
        let iv = payload.iv.toHexString()
        let publicKey = payload.publicKey.toHexString()
        let mac = payload.mac.toHexString()
        let cipherText = payload.cipherText.toHexString()
        return "\(iv)\(publicKey)\(mac)\(cipherText)"
    }
    
    private func decrypt(message: String, symmetricKey: Data) throws -> Data {
        let encryptionPayload = try deserializeIntoPayload(message: message)
        let decryptedString = try codec.decode(payload: encryptionPayload, sharedSecret: symmetricKey)
        guard let decryptedData = decryptedString.data(using: .utf8) else {
            throw DataConversionError.stringToDataFailed
        }
        return decryptedData
    }
    
    private func deserializeIntoPayload(message: String) throws -> EncryptionPayload {
        let data = Data(hex: message)
        guard data.count > EncryptionPayload.ivLength + EncryptionPayload.publicKeyLength + EncryptionPayload.macLength else {
            throw Error.messageToShort
        }
        let pubKeyRangeStartIndex = EncryptionPayload.ivLength
        let macStartIndex = pubKeyRangeStartIndex + EncryptionPayload.publicKeyLength
        let cipherTextStartIndex = macStartIndex + EncryptionPayload.macLength
        let iv = data.subdata(in: 0..<pubKeyRangeStartIndex)
        let pubKey = data.subdata(in: pubKeyRangeStartIndex..<macStartIndex)
        let mac = data.subdata(in: macStartIndex..<cipherTextStartIndex)
        let cipherText = data.subdata(in: cipherTextStartIndex..<data.count)
        return EncryptionPayload(iv: iv, publicKey: pubKey, mac: mac, cipherText: cipherText)
    }
}
