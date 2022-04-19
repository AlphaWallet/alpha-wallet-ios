// 

import Foundation
import XCTest
@testable import WalletConnectKMS

class HMACAuthenticatorTests: XCTestCase {
    let authenticationKey = Data(hex: "da4e6a3641db794441206145d6610d30bd5b403c624a5a4f69feb370cc59924d")
    let mac = Data(hex: "a1dfac369feea35ccb78c67be14f3a0574be41618c3d19bfaab179e92e4512c6")
    let dataToMac = Data(hex: "fd47c06a98f7f84c8d3b5a7154070a4d763979244226452948404d6251655468576d5a7134743777217a25432a462d4ad8ef04739c948000a2725d2ec66edcd6")
    
    var authenticator: HMACAuthenticating!
    
    override func setUp() {
        authenticator = HMACAuthenticator()
    }

    override func tearDown() {
        authenticator = nil
    }
    
    func testValidateAuthentication() {
        XCTAssertNoThrow(try authenticator.validateAuthentication(for: dataToMac, with: mac, using: authenticationKey))
    }
    
    func testGenerateAuthenticationDigest() {
        XCTAssertNotNil(try authenticator.generateAuthenticationDigest(for: Data(hex: "123"), using: authenticationKey))
    }
}
