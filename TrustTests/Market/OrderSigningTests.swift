import XCTest
@testable import Trust
import TrustKeystore
import RealmSwift
import BigInt

class OrderSigningTests : XCTestCase  {

    var contractAddress = "0xacDe9017473D7dC82ACFd0da601E4de291a7d6b0"
    let keystore = FakeEtherKeystore()
    let address: Address = .makeStormBird()

    func testSigningOrders() {
        
        var testOrdersList : Array<Order> = Array<Order>()
        //set up test orders
        var indices = [UInt16]()
        indices.append(14)
        
        let testOrder1 = Order(price: BigUInt("0")!,
                indices: indices,
                expiry: BigUInt("0")!,
                contractAddress: contractAddress,
                start: BigUInt("91239231313")!,
                count: 3
        )

        for _ in 0...2015 {
            testOrdersList.append(testOrder1)
        }

        let signOrders = OrderHandler()

        let account = keystore.getAccount(for: address)!

        //let signedOrders = try! signOrders.signOrders(orders: testOrdersList, account: account)
        //XCTAssertGreaterThanOrEqual(2016, signedOrders.count)

    }
    
}

