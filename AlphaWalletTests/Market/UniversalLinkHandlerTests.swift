//
// Created by James Sangalli on 24/3/18.
//

import Foundation
@testable import AlphaWallet
import XCTest
import BigInt

class UniversalLinkHandlerTests: XCTestCase {
    
    func testUniversalLinkParser() {
        let server: RPCServer = .main
        let testUrl = "https://aw.app/AQAAAAAAAACjNHyO0TRETCUWmHLJCmNg1Cs2kQFxEtQiQ269SZP2r2Y6CETiCqCE3HGQa63LYjsaCOccJi0mj9bpsmnZCwFkjVcNaaJ6Ed8lVU83UiGILQZ4CcFhHA=="
        guard let signedOrder = UniversalLinkHandler(server: server).parseUniversalLink(url: testUrl, prefix: RPCServer.main.magicLinkPrefix.absoluteString) else {
            XCTFail("Not able to extract an order from MagicLink")
            return
        }
        XCTAssertGreaterThanOrEqual(signedOrder.signature.count, 130)
        let url = UniversalLinkHandler(server: server).createUniversalLink(signedOrder: signedOrder, tokenType: TokenType.erc875)
        XCTAssertEqual(testUrl, url)
    }
    
    func testCreateUniversalLink() {
        var indices = [UInt16]()
        indices.append(1)
        let contractAddress = AlphaWallet.Address.make()
        let testOrder1 = Order(price: BigUInt("1000000000")!,
                               indices: indices,
                               expiry: BigUInt("0")!,
                               contractAddress: contractAddress,
                               count: 3,
                               nonce: BigUInt(0),
                               tokenIds: [BigUInt](),
                               spawnable: false,
                               nativeCurrencyDrop: false
        )
        
        var testOrders = [Order]()
        testOrders.append(testOrder1)
//        let account = try! EtherKeystore().getAccount(for: Address(string: "0x007bEe82BDd9e866b2bd114780a47f2261C684E3")!)
//        let signedOrder = try! OrderHandler().signOrders(orders: testOrders, account: account!)
//        let url = UniversalLinkHandler().createUniversalLink(signedOrder: signedOrder[0])
    }

    func testUniversalLinkParserDoesNotCrashWhenInvalid() {
        let server: RPCServer = .main
        let parser = UniversalLinkHandler(server: server)
        XCTAssertNil(parser.parseUniversalLink(url: "https://aw.app/", prefix: RPCServer.main.magicLinkPrefix.absoluteString))
        XCTAssertNil(parser.parseUniversalLink(url: "https://aw.app", prefix: RPCServer.main.magicLinkPrefix.absoluteString))
        XCTAssertNil(parser.parseUniversalLink(url: "http://aw.app", prefix: RPCServer.main.magicLinkPrefix.absoluteString))
        XCTAssertNil(parser.parseUniversalLink(url: "http://aw.app/", prefix: RPCServer.main.magicLinkPrefix.absoluteString))
    }
}
