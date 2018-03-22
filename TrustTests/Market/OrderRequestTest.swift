import Foundation
import XCTest
@testable import Trust
import TrustKeystore
import BigInt

class OrderRequestTest : XCTestCase  {

    var expectations = [XCTestExpectation]()
    
    func testGetOrders() {
        let expectation = self.expectation(description: "wait til callback")
        expectations.append(expectation)
        OrdersRequest().getOrders(callback: {
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

        var timestamp = NSDate().timeIntervalSince1970.description //1521562138
        timestamp = timestamp.substring(to: timestamp.count - 6);
        let ts = Int(timestamp)! + 300;
        let testOrder1 = Order(
                price: BigUInt("100000")!,
                indices: indices,
                expiry: BigUInt(String(ts))!,
                contractAddress: "bC9a1026A4BC6F0BA8Bbe486d1D09dA5732B39e4".lowercased(),
                start: BigUInt("500000210121213")!,
                count: 3
        )
        testOrdersList.append(testOrder1)
        let signedOrders = SignOrders().signOrders(orders: testOrdersList, account: account)
        let privateKey = keyStore.exportPrivateKey(account: account)
        let publicKey = try! Secp256k1.shared.pubKeyFromPrivateKey(from: privateKey.dematerialize())

        OrdersRequest.init().putOrderToServer(signedOrders: signedOrders, publicKey: publicKey.hexString, callback: {
            callback in
            print(callback)
            expectation.fulfill()
        })

        wait(for: expectations, timeout: 10)
    }
}

