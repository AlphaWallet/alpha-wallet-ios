import Foundation
import XCTest
@testable import Trust
import TrustKeystore
import BigInt

class OrderRequestTest : XCTestCase  {

    var expectations = [XCTestExpectation]()
    
    func testHttpCallToQueue() {
        let expectation = self.expectation(description: "wait til callback")
        expectations.append(expectation)
        OrdersRequest.init().getOrders(callback: {
            callback in
            print(callback)
            expectation.fulfill()
        })
        wait(for: expectations, timeout: 10)
    }
    
    func testPuttingOrderToQueue() {
        let expectation = self.expectation(description: "wait til callback")
        expectations.append(expectation)
        var testOrdersList : Array<Order> = Array<Order>()
        let keyStore = try! EtherKeystore()
        let account = try! keyStore.createAccount(password: "haha")
        //set up test orders
        var indices = [UInt16]()
        indices.append(1)
        indices.append(2)
        let testOrder1 = Order(price: BigUInt("100000")!, indices: indices,
                expiry: BigUInt("0")!, contractAddress: "007bee82bdd9e866b2bd114780a47f2261c684e3",
                start: BigUInt("500000210121213")!, count: 3)
        testOrdersList.append(testOrder1)
        let signOrders = SignOrders()
        var signedOrders = signOrders.signOrders(orders: testOrdersList, account: account).0
        let privateKey = try! keyStore.exportPrivateKey(account: account)
        let publicKey = try! Secp256k1.shared.pubKeyFromPrivateKey(from: privateKey.dematerialize())

        OrdersRequest.init().putOrderToServer(signedOrders: signedOrders, publicKey: publicKey.hex, callback: {
            callback in
            print(callback)
            expectation.fulfill()
        })

        wait(for: expectations, timeout: 10)
    }
}

