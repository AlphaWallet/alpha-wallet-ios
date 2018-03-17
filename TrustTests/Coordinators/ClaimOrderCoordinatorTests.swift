//
// Created by James Sangalli on 8/3/18.
//

import Foundation
import XCTest
@testable import Trust
import BigInt
import TrustKeystore

class ClaimOrderCoordinatorTests : XCTestCase {

    var expectations = [XCTestExpectation]()

    func testClaimOrder() {
        let claimOrderCoordinator = FakeClaimOrderCoordinator()
        let expectation = self.expectation(description: "wait til callback")
        expectations.append(expectation)
        var indices = [UInt16]()
        indices.append(3)
        indices.append(4)
        let expiry = BigUInt(0)
        let v = UInt8(27)
        let r = "0x9CAF1C785074F5948310CD1AA44CE2EFDA0AB19C308307610D7BA2C74604AE98"
        let s = "0x23D8D97AB44A2389043ECB3C1FB29C40EC702282DB6EE1D2B2204F8954E4B451"

        let token = TokenObject(
            contract: "0x84DFD837931954c6ca515516598468564308bde6",
            name: "MJ Comeback",
            symbol: "MJC",
            decimals: 0,
            value: "0",
            isCustom: true,
            isDisabled: false,
            isStormBird: true
        )

        
        claimOrderCoordinator.claimOrder(indices: indices, expiry: expiry, v: v, r: r, s: s) { result in
            switch result {

            case .success(let payload):
                let address: Address = .make()
                let transaction = UnconfirmedTransaction(
                    transferType: .stormBirdOrder(token),
                    value: BigInt("0"),
                    to: address,
                    data: Data(bytes: payload.hexa2Bytes),
                    gasLimit: .none,
                    gasPrice: 14400,
                    nonce: .none,
                    v: v,
                    r: r,
                    s: s,
                    expiry: expiry,
                    indices: indices
                )

                let configurator = TransactionConfigurator(
                    session: .make(),
                    account: .make(),
                    transaction: transaction
                )

                let signTransaction = configurator.signTransaction()
                let sendTransactionCoordinator = SendTransactionCoordinator(session: .make(), keystore: FakeKeystore(), confirmType: .signThenSend)
                sendTransactionCoordinator.send(transaction: signTransaction) { result in
                    print(result);
                    expectation.fulfill()
                }
            case .failure: break
            }
        }
        wait(for: expectations, timeout: 10)
    }
    
}
