import XCTest
@testable import Trust
import TrustKeystore
import RealmSwift
import BigInt

class OrderSigningTests : XCTestCase  {

    var contractAddress = "d9864b424447B758CdE90f8655Ff7cA4673956bf"

    func testSigningOrders() {
        
        var testOrdersList : Array<Order> = Array<Order>()
        var keyStore = FakeEtherKeystore()
        
        //set up test orders
        var indices = [UInt16]()
        indices.append(1)
        indices.append(2)
        
        let testOrder1 = Order(price: BigUInt("0")!, indices: indices,
                expiry: BigUInt("0")!, contractAddress: "bbf289d846208c16edc8474705c748aff07732db",
                start: BigUInt("91239231313")!, count: 3)
        testOrdersList.append(testOrder1)
        
        let signOrders = SignOrders()
        var account = keyStore.createAccount(password: "deleteOnceWorking")
        print(account.address)
        
        var signedOrders : Array<SignedOrder> = signOrders.signOrders(orders: testOrdersList, account: account)
        signedOrders[0].signature = "jrzcgpsnV7IPGE3nZQeHQk5vyZdy5c8rHk0R/iG7wpiK9NT730I//DN5Dg5fHs+s4ZFgOGQnk7cXLQROBs9NvgE="
        
        var signature = try! keyStore.signMessageData(Data(bytes: signedOrders[0].message), for: account).dematerialize().hexString
        print("v: " + Int(signature.substring(from: 128), radix: 16)!.description)
        print("r: 0x" + signature.substring(to: 64))
        print("s: 0x" + signature.substring(from: 64))
        //TODO optimize by keeping unlocked during signing
        //for i in 0...2015 {
        //    try! keyStore.signMessageData(Data(bytes: signedOrders[0].message), for: account)
        //}
        print(signedOrders.description)
    }
}

