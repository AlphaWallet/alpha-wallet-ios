// 

import Foundation
import WalletConnectUtils
@testable import WalletConnectKMS
@testable import WalletConnect


class SerializerMock: Serializing {
    var deserialized: Any!
    var serialized: String = ""
    
    func serialize(topic: String, encodable: Encodable) throws -> String {
        try serialize(json: try encodable.json(), agreementKeys: AgreementSecret(sharedSecret: Data(), publicKey: AgreementPrivateKey().publicKey))
    }
    func tryDeserialize<T: Codable>(topic: String, message: String) -> T? {
        try? deserialize(message: message, symmetricKey: Data())
    }
    func deserializeJsonRpc(topic: String, message: String) throws -> Result<JSONRPCResponse<AnyCodable>, JSONRPCErrorResponse> {
        .success(try deserialize(message: message, symmetricKey: Data()))
    }
    
    func deserialize<T>(message: String, symmetricKey: Data) throws -> T where T : Codable {
        if let deserializedModel = deserialized as? T {
            return deserializedModel
        } else {
            throw NSError.mock()
        }
    }
    
    func serialize(json: String, agreementKeys: AgreementSecret) throws -> String {
        return serialized
    }

}
