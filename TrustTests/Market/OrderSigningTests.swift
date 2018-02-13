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
        let testOrder1 = Order(price : BigInt(0), ticketIndices: indices, expiryTimeStamp: BigInt(0), contractAddress : "0x0dcd2f752394c41875e259e00bb44fd505297caf")
        testOrdersList.append(testOrder1)
        testSigningOrders()
    }

    func testSigningOrders() {
        let signOrders = SignOrders()
        var account = keyStore.createAccount(password: "deleteOnceWorking")
        print(account)
        var signedOrders : Array<SignedOrder> = signOrders.signOrders(orders: testOrdersList, account: account)

        var signature = try! keyStore.signMessage(((signedOrders.first?.message)!) as! String, for: account).dematerialize().hexString
        print("v: " + signature.substring(from: 128))
        print("r: 0x" + signature.substring(to: 64))
        print("s: 0x" + signature.substring(from: 64))

        //testing 2016 signature speed
        //for i  in 0 ... 2016 {
        //    try! keyStore.signMessage(((signedOrders.first?.message)! + i.description) as! String, for: account).dematerialize().hexString
        //}

        print(signedOrders.description)
    }
}

//0, [1,2], 28, "0xee42d612316d2c57b9b036e4e2e08e37546f43fccf45d816de82def9f3b9d54b", "0x17b4764146b5ffcc1faa85baa185288b9e03743a3ab4ada0af03e3a86772dd3f1c"