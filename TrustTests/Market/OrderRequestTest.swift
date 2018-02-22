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
    
    func testPostingOrderToQueue() {
        let expectation = self.expectation(description: "wait til callback")
        expectations.append(expectation)

        var testOrdersList : Array<Order> = Array<Order>()
        let keyStore = FakeEtherKeystore()
        let account = keyStore.createAccount(password: "haha")
        
        //set up test orders
        var indices = [UInt16]()
        indices.append(1)
        indices.append(2)
        
        let price = BigInt("1000000000")
        
        let expiry = BigInt("100000000")

        let testOrder1 = Order(price: price!, start: 1000, count: 3, expiryBuffer: expiry!, contractAddress: "007bee82bdd9e866b2bd114780a47f2261c684e3")
        testOrdersList.append(testOrder1)
        
        let signOrders = SignOrders()
        
        var signedOrders : Array<SignedOrder> = signOrders.signOrders(orders: testOrdersList, account: account)
        //TODO remove
        signedOrders[0].signature = "jrzcgpsnV7IPGE3nZQeHQk5vyZdy5c8rHk0R/iG7wpiK9NT730I//DN5Dg5fHs+s4ZFgOGQnk7cXLQROBs9NvgE="
        
        let privateKey = keyStore.exportPrivateKey(account: account)
        
        let publicKey = "qTIttEQTN2OhfJJimQInXPYwz9EohLtg2MFMrnCtTmSpMi20RBM3Y6F8kmKZAidc9jDP0SiEu2DYwUyucK1OZK"
        //try! Secp256k1.shared.getPublicKeyFromPrivateKey(from: privateKey.dematerialize()).hexString
        
        //TODO get public key
        OrdersRequest.init().giveOrderToServer(signedOrders: signedOrders, publicKeyHex: publicKey, callback: {
            callback in
            print(callback)
            expectation.fulfill()
        })

        wait(for: expectations, timeout: 10)
    }
}

