import XCTest
@testable import Trust
import TrustKeystore
import RealmSwift
import BigInt

class OrderSigningTests : XCTestCase  {

    func testSigningOrders() {

        var testOrdersList : Array<Order> = Array<Order>()
        var keyStore = FakeEtherKeystore()

        //set up test orders
        var indices = [UInt16]()
        indices.append(1)
        indices.append(2)
        let testOrder1 = Order(price : BigInt(0), ticketIndices: indices,
                expiryTimeStamp: BigInt(0), contractAddress : "d9864b424447B758CdE90f8655Ff7cA4673956bf")
        testOrdersList.append(testOrder1)

        let signOrders = SignOrders()
        var account = keyStore.createAccount(password: "deleteOnceWorking")
        print(account)

        var signedOrders : Array<SignedOrder> = signOrders.signOrders(orders: testOrdersList, account: account)

        var signature = try! keyStore.signMessageData(signedOrders.first?.message, for: account).dematerialize().hexString
        print("v: " + Int(signature.substring(from: 128), radix: 16)!.description)
        print("r: 0x" + signature.substring(to: 64))
        print("s: 0x" + signature.substring(from: 64))

        print(signedOrders.description)
    }
}

