//
// Created by James Sangalli on 2/3/18.
//
import Foundation
@testable import Trust
import XCTest
import BigInt

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
        let hexSig = try! keyStore.signMessageData(data, for: account).dematerialize().hexString
        //hex string should be cast into decimal
        XCTAssertGreaterThanOrEqual((BigUInt(hexSig, radix: 16)?.bitWidth)!, 0)
        print(BigUInt(hexSig, radix: 16))
    }

}