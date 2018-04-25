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
        let keystore = try! EtherKeystore()
        let claimOrderCoordinator = FakeClaimOrderCoordinator()
        let expectation = self.expectation(description: "wait til callback")
        expectations.append(expectation)
        var indices = [UInt16]()
        indices.append(14)
        let expiry = BigUInt("0")
        let v = UInt8(27)
        let r = "0x2d8e40406bf6175036ab1e1099b48590438bf48d429a8b209120fecd07894566"
        let s = "0x59ccf58ca36f681976228309fdd9de7e30e860084d9d63014fa79d48a25bb93d"

        let token = TokenObject(
            contract: "0xacDe9017473D7dC82ACFd0da601E4de291a7d6b0",
            name: "MJ Comeback",
            symbol: "MJC",
            decimals: 0,
            value: "0",
            isCustom: true,
            isDisabled: false,
            isStormBird: true
        )

        claimOrderCoordinator.claimOrder(indices: indices, expiry: expiry!, v: v, r: r, s: s) { result in
            switch result {
            case .success(let payload):
                let address: Address = .makeStormBird()
                let transaction = UnconfirmedTransaction(
                    transferType: .stormBirdOrder(token),
                    value: BigInt("0"),
                    to: address,
                    data: Data(bytes: payload.hexa2Bytes),
                    gasLimit: .none,
                    gasPrice: 200000,
                    nonce: .none,
                    v: v,
                    r: r,
                    s: s,
                    expiry: expiry,
                    indices: indices
                )

                let session: WalletSession = .makeStormBirdSession()

                let configurator = TransactionConfigurator(
                    session: session,
                    account: .make(),
                    transaction: transaction
                )

                let unsignedTransaction = configurator.formUnsignedTransaction()
                
                let account = keystore.createAccount(password: "test")
                
                let signedTransaction = UnsignedTransaction(value: unsignedTransaction.value,
                                                        account: account,
                                                        to: unsignedTransaction.to,
                                                        nonce: unsignedTransaction.nonce,
                                                        data: unsignedTransaction.data,
                                                        gasPrice: unsignedTransaction.gasPrice,
                                                        gasLimit: unsignedTransaction.gasLimit,
                                                        chainID: 3)
                
                
                let sendTransactionCoordinator = SendTransactionCoordinator(session: session,
                                                                            keystore: keystore,
                                                                            confirmType: .signThenSend)
                expectation.fulfill()
                //should not broadcast for a test
//                sendTransactionCoordinator.send(transaction: signedTransaction) { result in
//                    switch result {
//                    case .success(let res):
//                        print(res);
//                        expectation.fulfill()
//                    case .failure(let error):
//                        print(error);
//                    }
//                }
            case .failure: break
            }
        }
        wait(for: expectations, timeout: 10000)
    }
    
}
