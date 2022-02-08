//
// Created by James Sangalli on 2/3/18.
//
import Foundation
@testable import AlphaWallet
import XCTest
import BigInt
import WalletCore

class CreateRedeemTests: XCTestCase {
    let keyStore = FakeEtherKeystore()

    //when loading qr only include signature in decimal and the indices
    func testGenerateRedeem() {
        var token = [BigUInt]()
        token.append(1)
        token.append(2)
        let account = keyStore.createAccount()
        let message = CreateRedeem(token: TokenObject()).redeemMessage(tokenIds: token).0
        let data = message.data(using: String.Encoding.utf8)
        do {
            let signature = try keyStore.signMessageData(data!, for: account.dematerialize())
            //message and signature is to go in qr code
            debugLog("message: " + message)
            debugLog(try "signature: " + signature.dematerialize().hexString)
            //TODO no test?
        } catch {
            debugLog(error)
        }
    }
}
