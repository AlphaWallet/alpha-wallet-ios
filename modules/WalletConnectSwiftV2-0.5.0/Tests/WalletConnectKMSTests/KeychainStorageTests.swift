import XCTest
import CryptoKit
@testable import WalletConnectKMS

extension Curve25519.KeyAgreement.PrivateKey: GenericPasswordConvertible {}

final class KeychainStorageTests: XCTestCase {
    
    var sut: KeychainStorage!
    
    var fakeKeychain: KeychainServiceFake!
    
    let defaultIdentifier = "key"
    
    override func setUp() {
        fakeKeychain = KeychainServiceFake()
        sut = KeychainStorage(
            keychainService: fakeKeychain,
            serviceIdentifier: "")
    }
    
    override func tearDown() {
        try? sut.deleteAll()
        sut = nil
        fakeKeychain = nil
    }

    func testAdd() {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        XCTAssertNoThrow(try sut.add(privateKey, forKey: "id-1"))
        XCTAssertNoThrow(try sut.add(privateKey, forKey: "id-2"))
    }
    
    func testAddDuplicateItemError() {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        try? sut.add(privateKey, forKey: defaultIdentifier)
        XCTAssertThrowsError(try sut.add(privateKey, forKey: defaultIdentifier)) { error in
            guard let error = error as? KeychainError else { XCTFail(); return }
            XCTAssertEqual(error.status, errSecDuplicateItem)
        }
    }
    
    func testAddUnknownFailure() {
        fakeKeychain.errorStatus = errSecMissingEntitlement
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        XCTAssertThrowsError(try sut.add(privateKey, forKey: defaultIdentifier)) { error in
            XCTAssert(error is KeychainError)
        }
    }
    
    func testRead() {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        do {
            try sut.add(privateKey, forKey: defaultIdentifier)
            let retrievedKey: Curve25519.KeyAgreement.PrivateKey = try sut.read(key: defaultIdentifier)
            XCTAssertEqual(privateKey, retrievedKey)
        } catch {
            XCTFail()
        }
    }
    
    func testReadItemNotFoundFails() {
        do {
            let _: Curve25519.KeyAgreement.PrivateKey = try sut.read(key: "")
            XCTFail()
        } catch {
            guard let error = error as? KeychainError else { XCTFail(); return }
            XCTAssertEqual(error.status, errSecItemNotFound)
        }
    }
    
    func testReadUnknownFailure() {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        do {
            try sut.add(privateKey, forKey: defaultIdentifier)
            fakeKeychain.errorStatus = errSecMissingEntitlement
            let _: Curve25519.KeyAgreement.PrivateKey = try sut.read(key: defaultIdentifier)
            XCTFail()
        } catch {
            XCTAssert(error is KeychainError)
        }
    }
    
    func testUpdate() {
        let privateKeyA = Curve25519.KeyAgreement.PrivateKey()
        let privateKeyB = Curve25519.KeyAgreement.PrivateKey()
        do {
            try sut.add(privateKeyA, forKey: defaultIdentifier)
            try sut.update(privateKeyB, forKey: defaultIdentifier)
            let retrievedKey: Curve25519.KeyAgreement.PrivateKey = try sut.read(key: defaultIdentifier)
            XCTAssertEqual(privateKeyB, retrievedKey)
        } catch {
            XCTFail()
        }
    }
    
    func testUpdateItemNotFoundFails() {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        XCTAssertThrowsError(try sut.update(privateKey, forKey: defaultIdentifier)) { error in
            guard let error = error as? KeychainError else { XCTFail(); return }
            XCTAssertEqual(error.status, errSecItemNotFound)
        }
    }
    
    func testUpdateUnknownFailure() {
        let privateKeyA = Curve25519.KeyAgreement.PrivateKey()
        let privateKeyB = Curve25519.KeyAgreement.PrivateKey()
        do {
            try sut.add(privateKeyA, forKey: defaultIdentifier)
            fakeKeychain.errorStatus = errSecMissingEntitlement
            try sut.update(privateKeyB, forKey: defaultIdentifier)
            XCTFail()
        } catch {
            XCTAssert(error is KeychainError)
        }
    }
    
    func testDelete() {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        try? sut.add(privateKey, forKey: defaultIdentifier)
        do {
            try sut.delete(key: defaultIdentifier)
            XCTAssertNil(try sut.readData(key: defaultIdentifier))
        } catch {
            XCTFail()
        }
    }
    
    func testDeleteNotFoundDoesntThrowError() {
        XCTAssertNoThrow(try sut.delete(key: defaultIdentifier))
    }
    
    func testDeleteUnknownFailure() {
        fakeKeychain.errorStatus = errSecMissingEntitlement
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        try? sut.add(privateKey, forKey: defaultIdentifier)
        do {
            try sut.delete(key: defaultIdentifier)
            XCTFail()
        } catch {
            XCTAssert(error is KeychainError)
        }
    }
    
    func testDeleteAll() {
        do {
            let keys = (1...10).map { "key-\($0)" }
            try keys.forEach {
                let privateKey = Curve25519.KeyAgreement.PrivateKey()
                try sut.add(privateKey, forKey: $0)
            }
            try sut.deleteAll()
            try keys.forEach {
                XCTAssertNil(try sut.readData(key: $0))
            }
        } catch {
            XCTFail()
        }
    }
    
    func testDeleteAllFromCleanKeychain() {
        XCTAssertThrowsError(try sut.deleteAll()) { error in
            XCTAssert(error is KeychainError)
        }
    }
}
