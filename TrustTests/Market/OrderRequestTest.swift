import Foundation
import XCTest
@testable import Trust
import TrustKeystore

class OrderRequestTest : XCTestCase  {
    
    func testHttpCallToQueue() {
        OrdersRequest.init().getOrders(callback: {
            callback in print(callback)
        })
    }
    
    func testPostingOrderToQueue() {
        var testOrdersList : Array<Order> = Array<Order>()
        let keyStore = FakeEtherKeystore()
        let account = keyStore.createAccount(password: "haha")
        
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
        
        let signedOrders : Array<SignedOrder> = signOrders.signOrders(orders: testOrdersList, account: account)
        
        let privateKey = keyStore.exportPrivateKey(account: account)
        
        let publicKey = "qTIttEQTN2OhfJJimQInXPYwz9EohLtg2MFMrnCtTmSpMi20RBM3Y6F8kmKZAidc9jDP0SiEu2DYwUyucK1OZK"
        //try! Secp256k1.shared.getPublicKeyFromPrivateKey(from: privateKey.dematerialize()).hexString
        
        //TODO get public key or change server to take address
//        OrdersRequest.init().giveOrderToServer(signedOrders: signedOrders, publicKeyHex: publicKey, callback: {
//            callback in
//            print(callback)
//        })
    }
}

