
import Foundation
import XCTest
@testable import WalletConnectKMS

class AES_256_CBC_HMAC_SHA256_Codec_Test: XCTestCase {
    let message = "Test Message"
    var codec: AES_256_CBC_HMAC_SHA256_Codec!
    let agreementKeys = AgreementSecret(
        sharedSecret: Data(hex: "404D635166546A576E5A7234753777217A25432A462D4A614E645267556B5870"),
        publicKey: try! AgreementPublicKey(rawRepresentation: Data(hex: "763979244226452948404d6251655468576d5a7134743777217a25432a462d4a")))

    override func setUp() {
        codec = AES_256_CBC_HMAC_SHA256_Codec()
    }

    override func tearDown() {
        codec = nil
    }

    func testEncodeDecode() {
        let encryptionPayload = try! codec.encode(plainText: message, agreementKeys: agreementKeys)
        let decodedMessage = try! codec.decode(payload: encryptionPayload, sharedSecret: agreementKeys.sharedSecret)
        XCTAssertEqual(message, decodedMessage)
    }
    
    func testThrowErrorOnUnauthenticCiphertext() {
        var encryptedPayload = try! codec.encode(plainText: message, agreementKeys: agreementKeys)
        encryptedPayload.cipherText.append(Data(hex: "123"))
        XCTAssertThrowsError(try codec.decode(payload: encryptedPayload, sharedSecret: agreementKeys.sharedSecret))
    }
    
    func testNotThrowOnAuthenticCiphertext() {
        let encryptedPayload = try! codec.encode(plainText: message, agreementKeys: agreementKeys)
        XCTAssertNoThrow(try codec.decode(payload: encryptedPayload, sharedSecret: agreementKeys.sharedSecret))
    }
}
