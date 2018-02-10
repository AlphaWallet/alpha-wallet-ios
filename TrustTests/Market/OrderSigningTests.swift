import XCTest
@testable import Trust
import TrustKeystore
import RealmSwift
import BigInt

//TODO remove and replace with main struct
struct Order {
    var price: BigInt?;
    var ticketIndices: [Int]?;
    var expiryTimeStamp: BigInt?;
    var contractAddress: String?;
}

class OrderSigningTests : XCTestCase
{
    //let account = self.createAccount("test")
    var testOrdersList : [Order] = []

    func testInit()
    {
        //set up test orders
        let indices = [1, 2]
        let testOrder1 = Order(price : 1, ticketIndices : indices, expiryTimeStamp : 0, contractAddress : "0xd9864b424447B758CdE90f8655Ff7cA4673956bf")
        testOrdersList.append(testOrder1)
    }

    func testSigningOrders()
    {
        //var signOrders = SignOrders()
        //TODO once working, do this 2016 times as a test
        //signOrders.signOrder(testOrdersList, account)
    }
}


