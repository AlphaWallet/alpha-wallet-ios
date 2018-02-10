//import XCTest
//@testable import Trust
//import TrustKeystore
//import RealmSwift
//
//class OrderSigningTests : XCTestCase {
//
//    let account : Account = self.createAccount("test")
//    var testOrdersList : Array<Order>
//
//    func testInit()
//    {
//        //set up test orders
//        let testOrder1 = Order()
//        testOrder1.price = BigInt.min
//        testOrder1.expiryTimeStamp = BigInt.min
//        testOrder1.contractAddress = SignOrders.CONTRACT_ADDR
//        //in test we will create signatures
//        testOrder1.v = 27
//        testOrder1.hexR = "0x9CAF1C785074F5948310CD1AA44CE2EFDA0AB19C308307610D7BA2C74604AE98"
//        testOrder1.hexS = "0x23D8D97AB44A2389043ECB3C1FB29C40EC702282DB6EE1D2B2204F8954E4B451"
//        testOrdersList.append(testOrder1)
//
//        testSigningOrders()
//    }
//
//    func testSigningOrders()
//    {
//        var signOrders = SignOrders()
//        //TODO once working, do this 2016 times as a test
//        signOrders.signOrder(testOrders, account)
//    }
//
//}
