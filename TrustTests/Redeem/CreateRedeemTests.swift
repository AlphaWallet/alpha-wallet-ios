//
// Created by James Sangalli on 2/3/18.
//
import Foundation
@testable import Trust
import XCTest
import BigInt

class CreateRedeemTests: XCTestCase {

    var keyStore = FakeEtherKeystore()

    //when loading qr only include signature in decimal and the indices
    func testGenerateRedeem() {
        var indices = [UInt16]()
        indices.append(1)
        indices.append(2)
        let account = keyStore.createAccount(password: "test")
        let message = CreateRedeem.init().redeemMessage(ticketIndices: indices).0
        print(message)
        let data = message.data(using: String.Encoding.utf8)

        let signature = keyStore.signMessageData(data!, for: account)
        //message and signature is to go in qr code
        print("message: " + message)
        print(try! "signature: " + signature.dematerialize().hexString)
    }

}
