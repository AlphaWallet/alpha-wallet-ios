// 

import Foundation
import CryptoKit

protocol HMACAuthenticating {
    func validateAuthentication(for data: Data, with mac: Data, using symmetricKey: Data) throws
    func generateAuthenticationDigest(for data: Data, using symmetricKey: Data) throws -> Data
}

class HMACAuthenticator: HMACAuthenticating {
    func validateAuthentication(for data: Data, with mac: Data, using symmetricKey: Data) throws {
        let newMacDigest = try generateAuthenticationDigest(for: data, using: symmetricKey)
        if mac != newMacDigest {
            throw HMACAuthenticatorError.invalidAuthenticationCode
        }
    }
    
    func generateAuthenticationDigest(for data: Data, using symmetricKey: Data)  throws -> Data {
        let key = SymmetricKey(data: symmetricKey)
        let hmac = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(hmac)
    }
}
