//
// Created by James Sangalli on 2019-08-15.
//

import Foundation
import XCTest
@testable import AlphaWallet
import AWSLambda

class TokenScriptProofOfAddressVerifierTests: XCTestCase {

    func test() {
        let result = TokenScriptProofOfAddressVerifier().deriveTrustAddress(tsml: "String", contractAddress: "String")
        print(result)
    }
}
