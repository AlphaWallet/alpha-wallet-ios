//
// Created by James Sangalli on 2/3/18.
//
import Foundation
@testable import Trust
import XCTest

class CreateRedeemTests: XCTestCase {

    var keyStore = FakeEtherKeystore()

    func testGenerateRedeem() {
        var indices = [UInt16]()
        indices.append(1)
        indices.append(2)
        let account = keyStore.createAccount(password: "test")
        XCTAssertNoThrow(CreateRedeem.init().generateRedeem(
                ticketIndices: indices))
        let data = CreateRedeem.init().generateRedeem(ticketIndices: indices)
        print(try! keyStore.signMessageData(data, for: account).dematerialize().hexString)
    }

}