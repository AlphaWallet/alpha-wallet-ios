import XCTest
@testable import Trust
import TrustKeystore
import RealmSwift
import BigInt

class OrderSigningTests : XCTestCase  {

    //TODO fix signing errors

//TODO check that hex to bytes is actually functional
//    the plan is to sign small chunks at a time till the
//    signature matches all of the data. first just sign the price with zeros, if this works then iterate on top

    func testSigningOrders() {

        var testOrdersList : Array<Order> = Array<Order>()
        var keyStore = FakeEtherKeystore()

        //set up test orders
        var indices = [UInt16]()
        indices.append(1)
        indices.append(2)
        let testOrder1 = Order(price : BigInt(0), ticketIndices: indices,
                expiryTimeStamp: BigInt(0), contractAddress : "0x9dd1e8169e76a9226b07ab9f85cc20a5e1ed44dd")
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

//0,[1,2], 27, "0x97d4ccdf86b03af7bf81f2d61e1e98f8f86c55c1eaa737e562c9471ea868c03a", "0x5b9f9976d4507245cdc090538cbb97122fe3c71d84bf3f42ad03feed267ee72f1b"
