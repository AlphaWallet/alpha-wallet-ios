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
        let testUrl = "https://app.awallet.io/AAGGoFq8Ule8mhAmpLxvC6i75IbR0J2lcys55AECAwQFBgcICYvWi5I+Tl5m9XumBD5jLIm6i39kD7F40UW4BaJDEVOWLTYz3kek7wjT7Bn+2w0NCiyx7zWuvseTA8qfoIqCIxob"
        let signedOrder = UniversalLinkHandler().parseURL(url: testUrl)
        XCTAssertGreaterThanOrEqual(signedOrder.signature.count, 130)
        let url = UniversalLinkHandler().createUniversalLink(signedOrder: signedOrder)
        print(url)
        XCTAssertEqual(testUrl, url)
    }
    
    func testCreateUniversalLink() {
        var indices = [UInt16]()
        indices.append(150)
        indices.append(890)
        indices.append(12)
        
        let testOrder1 = Order(price: BigUInt("0")!,
                               indices: indices,
                               expiry: BigUInt("0")!,
                               contractAddress: "0xbC9a1026A4BC6F0BA8Bbe486d1D09dA5732B39e4",
                               start: BigUInt("91239231313")!,
                               count: 3
        )
        
        var testOrders = [Order]()
        testOrders.append(testOrder1)
        //let account = try! EtherKeystore().getAccount(for: Address(string: "0x007bEe82BDd9e866b2bd114780a47f2261C684E3")!)
        //let signedOrder = try! OrderHandler().signOrders(orders: testOrders, account: account!)
        //let url = UniversalLinkHandler().createUniversalLink(signedOrder: signedOrder[0])
        //print(url)
    }

}
