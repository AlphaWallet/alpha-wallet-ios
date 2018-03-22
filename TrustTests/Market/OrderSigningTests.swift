import XCTest
@testable import Trust
import TrustKeystore
import RealmSwift
import BigInt

class OrderSigningTests : XCTestCase  {

    var contractAddress = "0xacDe9017473D7dC82ACFd0da601E4de291a7d6b0"
    var keyStore = try! EtherKeystore()

    func testSigningOrders() {
        
        var testOrdersList : Array<Order> = Array<Order>()
        //set up test orders
        var indices = [UInt16]()
        indices.append(14)
        
        let testOrder1 = Order(price: BigUInt("0")!, indices: indices,
                expiry: BigUInt("0")!, contractAddress: contractAddress,
                start: BigUInt("91239231313")!, count: 3)
        testOrdersList.append(testOrder1)
        
        let signOrders = SignOrders()
        let account = keyStore.getAccount(for: Address(string: "0x007bEe82BDd9e866b2bd114780a47f2261C684E3")!)!
        print(account.address)
        
        var signedOrders = signOrders.signOrders(orders: testOrdersList, account: account)
        
        let signature = try! keyStore.signMessageData(Data(bytes: signedOrders[0].message), for: account).dematerialize().hexString

        print("v: " + Int(signature.substring(from: 128), radix: 16)!.description)
        print("r: 0x" + signature.substring(to: 64))
        print("s: 0x" + signature.substring(from: 64, to: 128))
        
        //test signing speed for bulk orders
        var bulkMessages = [Data]()
        
        for _ in 0...2015 {
            bulkMessages.append(Data(bytes: signedOrders[0].message))
        }
    
        print(account.address)
        
        keyStore.signMessageBulk(bulkMessages, for: account)

        print(signedOrders.description)
    }
    
}

