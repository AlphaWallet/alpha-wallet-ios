//
// Created by James Sangalli on 2/3/18.
//
import Foundation
@testable import AlphaWallet
import XCTest
import BigInt
import AlphaWalletLogger
import AlphaWalletFoundation
import Combine

class CreateRedeemTests: XCTestCase {
    let keyStore = FakeEtherKeystore()
    private var cancellable = Set<AnyCancellable>()

    //when loading qr only include signature in decimal and the indices
    func testGenerateRedeem() {
        var token = [BigUInt]()
        token.append(1)
        token.append(2)
        let message = CreateRedeem(token: Token()).redeemMessage(tokenIds: token).0
        let data = message.data(using: String.Encoding.utf8)
        let expectation = self.expectation(description: "Wait for a new wallet")
        keyStore.createHDWallet()
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    XCTFail("Failure to import wallet: \(error)")
                }

                expectation.fulfill()
            }, receiveValue: { [keyStore] account in
                Task {
                    do {
                        let signature = await keyStore.signMessageData(data!, for: account.address, prompt: R.string.localizable.keystoreAccessKeySign())
                        //message and signature is to go in qr code
                        verboseLog("message: " + message)
                        verboseLog(try "signature: " + signature.get().hexString)
                        //TODO no test?
                    } catch {
                        warnLog(error)
                    }
                }
            }).store(in: &cancellable)

        wait(for: [expectation], timeout: 3)
    }
}
