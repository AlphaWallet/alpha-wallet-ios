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

        //TODO fix signature issues
        var signedOrders : Array<SignedOrder> = signOrders.signOrders(orders: testOrdersList, account: account)

        signedOrders[0].signature = "z8lFVctNXQLCSxTvC/7cAkuYMUyIg0HddtKsxCuBJ+sZlhYFKPUsCreIRqtkcPlTVaNM2GjIEVT5JQok0iK5KQE="

        let privateKey = keyStore.exportPrivateKey(account: account)
        
        let publicKey = try! Secp256k1.shared.pubKeyFromPrivateKey(from: privateKey.dematerialize()).hexString

        OrdersRequest.init().giveOrderToServer(signedOrders: signedOrders, publicKeyHex: publicKey, callback: {
            callback in
            print(callback)
            expectation.fulfill()
        })

        wait(for: expectations, timeout: 10)
    }
}

