//
// Created by James Sangalli on 24/3/18.
//

import Foundation
@testable import Trust
import XCTest
import BigInt
import TrustKeystore

class UniversalLinkHandlerTests: XCTestCase {
    
    func testUniversalLinkParser() {
        let testUrl = "https://app.awallet.io/AAAAAAAAAACjNHyO0TRETCUWmHLJCmNg1Cs2kQFxEtQiQ269SZP2r2Y6CETiCqCE3HGQa63LYjsaCOccJi0mj9bpsmnZCwFkjVcNaaJ6Ed8lVU83UiGILQZ4CcFhHA=="
        let signedOrder = UniversalLinkHandler().parseUniversalLink(url: testUrl)
        XCTAssertGreaterThanOrEqual(signedOrder.signature.count, 130)
        let url = UniversalLinkHandler().createUniversalLink(signedOrder: signedOrder)
        print(url)
        XCTAssertEqual(testUrl, url)
    }
    
    func testCreateUniversalLink() {
        var indices = [UInt16]()
        indices.append(1)
        let contractAddress = XMLHandler().getAddressFromXML(server: Config().server).eip55String
        let testOrder1 = Order(price: BigUInt("1000000000")!,
                               indices: indices,
                               expiry: BigUInt("0")!,
                               contractAddress: contractAddress,
                               start: BigUInt("91239231313")!,
                               count: 3
        )
        
        var testOrders = [Order]()
        testOrders.append(testOrder1)
//        let account = try! EtherKeystore().getAccount(for: Address(string: "0x007bEe82BDd9e866b2bd114780a47f2261C684E3")!)
//        let signedOrder = try! OrderHandler().signOrders(orders: testOrders, account: account!)
//        let url = UniversalLinkHandler().createUniversalLink(signedOrder: signedOrder[0])
//        print(url)
    }

}
