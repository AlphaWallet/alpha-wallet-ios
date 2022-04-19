// 

import Foundation
import CryptoKit

protocol Codec {
    var hmacAuthenticator: HMACAuthenticating {get}
    func encode(plainText: String, agreementKeys: AgreementSecret) throws -> EncryptionPayload
    func decode(payload: EncryptionPayload, sharedSecret: Data) throws -> String
}

class AES_256_CBC_HMAC_SHA256_Codec: Codec {
    let hmacAuthenticator: HMACAuthenticating
    
    init(hmacAuthenticator: HMACAuthenticating = HMACAuthenticator()) {
        self.hmacAuthenticator = hmacAuthenticator
    }
    
    func encode(plainText: String, agreementKeys: AgreementSecret) throws -> EncryptionPayload {
        let (encryptionKey, authenticationKey) = getKeyPair(from: agreementKeys.sharedSecret)
        let plainTextData = try data(string: plainText)
        let (cipherText, iv) = try encrypt(key: encryptionKey, data: plainTextData)
        let dataToMac = iv + agreementKeys.publicKey.rawRepresentation + cipherText
        let hmac = try hmacAuthenticator.generateAuthenticationDigest(for: dataToMac, using: authenticationKey)
        return EncryptionPayload(iv: iv,
                                 publicKey: agreementKeys.publicKey.rawRepresentation,
                                 mac: hmac,
                                 cipherText: cipherText)
    }
    
    func decode(payload: EncryptionPayload, sharedSecret: Data) throws -> String {
        let (decryptionKey, authenticationKey) = getKeyPair(from: sharedSecret)
        let dataToMac = payload.iv + payload.publicKey + payload.cipherText
        try hmacAuthenticator.validateAuthentication(for: dataToMac, with: payload.mac, using: authenticationKey)
        let plainTextData = try decrypt(key: decryptionKey, data: payload.cipherText, iv: payload.iv)
        let plainText = try string(data: plainTextData)
        return plainText
    }

    private func encrypt(key: Data, data: Data) throws -> (cipherText: Data, iv: Data) {
        let iv = AES.randomIV()
        let symKey = SymmetricKey(data: key)
        let cipherText = try AES.CBC.encrypt(data, using: symKey, iv: iv)
        return (cipherText, iv)
    }

    private func decrypt(key: Data, data: Data, iv: Data) throws -> Data {
        let symKey = SymmetricKey(data: key)
        let plainText = try AES.CBC.decrypt(data, using: symKey, iv: iv)
        return plainText
    }

    private func data(string: String) throws -> Data {
        if let data = string.data(using: .utf8) {
            return data
        } else {
            throw CodecError.stringToDataFailed(string)
        }
    }

    private func string(data: Data) throws -> String {
        if let string = String(data: data, encoding: .utf8) {
            return string
        } else {
            throw CodecError.dataToStringFailed(data)
        }
    }

    private func getKeyPair(from keyData: Data) -> (Data, Data) {
        let keySha512 = keyData.sha512()
        let key1 = keySha512.subdata(in: 0..<32)
        let key2 = keySha512.subdata(in: 32..<64)
        return (key1, key2)
    }
}
