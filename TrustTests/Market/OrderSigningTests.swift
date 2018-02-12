import XCTest
@testable import Trust
import TrustKeystore
import RealmSwift
import BigInt

class OrderSigningTests : XCTestCase  {
    //let account = self.createAccount("test")
    var testOrdersList : Array<Order> = Array<Order>()
    var keyStore = FakeEtherKeystore()

    func testInit() {
        //set up test orders
        var indices = [UInt16]()
        indices.append(1)
        indices.append(2)
        let testOrder1 = Order(price : BigInt(0), ticketIndices: indices, expiryTimeStamp: BigInt(0), contractAddress : "0xd9864b424447B758CdE90f8655Ff7cA4673956bf")
        testOrdersList.append(testOrder1)
        testSigningOrders()
    }

    func testSigningOrders() {
        let signOrders = SignOrders()
        //TODO once working, do this 2016 times as a test
        var account = keyStore.createAccount(password: "deleteOnceWorking")
        var signedOrders : Array<SignedOrder> = signOrders.signOrders(orders: testOrdersList, account: account)
        print(signedOrders.popLast())
    }
}
