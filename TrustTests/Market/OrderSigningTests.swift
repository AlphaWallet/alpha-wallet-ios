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
        
        var price = [UInt8]()
        price.append(1) //price is 1 wei
        
        var expiry = [UInt8]()
        expiry.append(0)
        
        let testOrder1 = Order(price : price, ticketIndices: indices,
                               expiryBuffer: expiry, contractAddress : "d9864b424447B758CdE90f8655Ff7cA4673956bf")
        testOrdersList.append(testOrder1)
        
        let signOrders = SignOrders()
        var account = keyStore.createAccount(password: "deleteOnceWorking")
        print(account.address)
        
        var signedOrders : Array<SignedOrder> = signOrders.signOrders(orders: testOrdersList, account: account)
        
        var signature = try! keyStore.signMessageData(signedOrders.first?.message, for: account).dematerialize().hexString
        print("v: " + Int(signature.substring(from: 128), radix: 16)!.description)
        print("r: 0x" + signature.substring(to: 64))
        print("s: 0x" + signature.substring(from: 64))
        
//        for i in 0...2016 {
//            try! keyStore.signMessageData((signedOrders.first?.message)!, for: account)
//        }
//
        print(signedOrders.description)
    }
}

