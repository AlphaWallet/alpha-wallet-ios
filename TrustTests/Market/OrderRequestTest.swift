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
        let keyStore = FakeEtherKeystore()
        let account = keyStore.createAccount(password: "haha")
        
        //set up test orders
        var indices = [UInt16]()
        indices.append(1)
        indices.append(2)
        
        var price = [UInt8]()
        var expiry = [UInt8]()
        price.append(0)
        expiry.append(0)

        let testOrder1 = Order(price: price, indices: indices,
                expiry: expiry, contractAddress: "007bee82bdd9e866b2bd114780a47f2261c684e3",
                start: BigInt("500000210121213"), count: 3)
        testOrdersList.append(testOrder1)
        
        let signOrders = SignOrders()

        //TODO fix signature issues
        var signedOrders : Array<SignedOrder> = signOrders.signOrders(orders: testOrdersList, account: account)

        signedOrders[0].signature = "0x1cae08113567db5303fb1ed1b157fbc8c7247aa" +
                "9689ee76902d731c9806ab9853d8fcded6145fc7ebe5c32e41e247b315" +
                "b2b23f41dcb3acd17d01a9f6140669f1c"

        let privateKey = keyStore.exportPrivateKey(account: account)
        
        let publicKey = try! Secp256k1.shared.pubKeyFromPrivateKey(from:
        privateKey.dematerialize()).hexString

        OrdersRequest.init().putOrderToServer(signedOrders: signedOrders, publicKey: publicKey, callback: {
            callback in
            print(callback)
            expectation.fulfill()
        })

        wait(for: expectations, timeout: 10)
    }
}

