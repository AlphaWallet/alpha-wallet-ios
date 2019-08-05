//
// Created by James Sangalli on 2/3/18.
//
import Foundation
@testable import AlphaWallet
import XCTest
import BigInt
import TrustWalletCore

class CreateRedeemTests: XCTestCase {
    let keyStore = FakeEtherKeystore()

    //when loading qr only include signature in decimal and the indices
    func testGenerateRedeem() {
        var indices = [UInt16]()
        indices.append(1)
        indices.append(2)
        let account = keyStore.createAccount()
        let message = CreateRedeem(token: TokenObject()).redeemMessage(tokenIndices: indices).0
        print(message)
        let data = message.data(using: String.Encoding.utf8)

        let signature = try! keyStore.signMessageData(data!, for: account.dematerialize())
        //message and signature is to go in qr code
        print("message: " + message)
        print(try! "signature: " + signature.dematerialize().hexString)
        //TODO no test?
    }
}
