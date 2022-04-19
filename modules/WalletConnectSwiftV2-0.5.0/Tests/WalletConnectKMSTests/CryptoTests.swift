import XCTest
@testable import WalletConnectKMS
@testable import TestingUtils

fileprivate extension Error {
    var isKeyNotFoundError: Bool {
        guard case .keyNotFound = self as? KeyManagementService.Error else { return false }
        return true
    }
}

class CryptoTests: XCTestCase {
    
    var crypto: KeyManagementService!

    override func setUp() {
        crypto = KeyManagementService(keychain: KeychainStorageMock())
    }

    override func tearDown() {
        crypto = nil
    }
    
    func testCreateKeyPair() throws {
        let publicKey = try crypto.createX25519KeyPair()
        let privateKey = try crypto.getPrivateKey(for: publicKey)
        XCTAssertNotNil(privateKey)
        XCTAssertEqual(privateKey?.publicKey, publicKey)
    }
    
    func testPrivateKeyRoundTrip() throws {
        let privateKey = AgreementPrivateKey()
        let publicKey = privateKey.publicKey
        XCTAssertNil(try crypto.getPrivateKey(for: publicKey))
        try crypto.setPrivateKey(privateKey)
        let storedPrivateKey = try crypto.getPrivateKey(for: publicKey)
        XCTAssertEqual(privateKey, storedPrivateKey)
    }
    
    func testDeletePrivateKey() throws {
        let privateKey = AgreementPrivateKey()
        let publicKey = privateKey.publicKey
        try crypto.setPrivateKey(privateKey)
        crypto.deletePrivateKey(for: publicKey.hexRepresentation)
        XCTAssertNil(try crypto.getPrivateKey(for: publicKey))
    }
    
    func testAgreementSecretRoundTrip() throws {
        let topic = "topic"
        XCTAssertNil(try crypto.getAgreementSecret(for: topic))
        let agreementKeys = AgreementSecret.stub()
        try? crypto.setAgreementSecret(agreementKeys, topic: topic)
        let storedAgreementSecret = try crypto.getAgreementSecret(for: topic)
        XCTAssertEqual(agreementKeys, storedAgreementSecret)
    }
    
    func testDeleteAgreementSecret() throws {
        let topic = "topic"
        let agreementKeys = AgreementSecret.stub()
        try? crypto.setAgreementSecret(agreementKeys, topic: topic)
        crypto.deleteAgreementSecret(for: topic)
        XCTAssertNil(try crypto.getAgreementSecret(for: topic))
    }
    
    func testGenerateX25519Agreement() throws {
        let privateKeyA = try AgreementPrivateKey(rawRepresentation: CryptoTestData._privateKeyA)
        let privateKeyB = try AgreementPrivateKey(rawRepresentation: CryptoTestData._privateKeyB)
        let agreementSecretA = try KeyManagementService.generateAgreementSecret(from: privateKeyA, peerPublicKey: privateKeyB.publicKey.hexRepresentation)
        let agreementSecretB = try KeyManagementService.generateAgreementSecret(from: privateKeyB, peerPublicKey: privateKeyA.publicKey.hexRepresentation)
        XCTAssertEqual(agreementSecretA.sharedSecret, agreementSecretB.sharedSecret)
        XCTAssertEqual(agreementSecretA.sharedSecret, CryptoTestData.expectedSharedSecret)
    }
    
    func testGenerateX25519AgreementRandomKeys() throws {
        let privateKeyA = AgreementPrivateKey()
        let privateKeyB = AgreementPrivateKey()
        let agreementSecretA = try KeyManagementService.generateAgreementSecret(from: privateKeyA, peerPublicKey: privateKeyB.publicKey.hexRepresentation)
        let agreementSecretB = try KeyManagementService.generateAgreementSecret(from: privateKeyB, peerPublicKey: privateKeyA.publicKey.hexRepresentation)
        XCTAssertEqual(agreementSecretA.sharedSecret, agreementSecretB.sharedSecret)
    }
    
    func testPerformKeyAgreement() throws {
        let privateKeySelf = AgreementPrivateKey()
        let privateKeyPeer = AgreementPrivateKey()
        let peerSecret = try KeyManagementService.generateAgreementSecret(from: privateKeyPeer, peerPublicKey: privateKeySelf.publicKey.hexRepresentation)
        try crypto.setPrivateKey(privateKeySelf)
        let selfSecret = try crypto.performKeyAgreement(selfPublicKey: privateKeySelf.publicKey, peerPublicKey: privateKeyPeer.publicKey.hexRepresentation)
        XCTAssertEqual(selfSecret.sharedSecret, peerSecret.sharedSecret)
    }
    
    func testPerformKeyAgreementFailure() {
        let publicKeySelf = AgreementPrivateKey().publicKey
        let publicKeyPeer = AgreementPrivateKey().publicKey.hexRepresentation
        XCTAssertThrowsError(try crypto.performKeyAgreement(selfPublicKey: publicKeySelf, peerPublicKey: publicKeyPeer)) { error in
            XCTAssert(error.isKeyNotFoundError)
        }
    }
}
