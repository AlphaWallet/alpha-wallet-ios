//
// Created by James Sangalli on 24/3/18.
//

import Foundation
@testable import Trust
import XCTest

class UniversalLinkHandlerTests: XCTestCase {

    func testUniversalLinkParser() {
        let testUrl = "https://app.awallet.io/AA9CQAAAAAC8mhAmpLxvC6i75IbR0J2lcys55IDwAoKW" +
                "hOr6d7KY+8hNPvg7BADzHG9wEdp+nfFuaoeZzZ5PskIO9ym+0j0VxiTh6uyb7et3F/Y2HcgvcqNTA0xZ1gE="

        let signedOrder: SignedOrder = UniversalLinkHandler.parseURL(url: testUrl)

        print(signedOrder.signature)
        XCTAssertGreaterThanOrEqual(signedOrder.signature.count, 130)

        let url = UniversalLinkHandler.createUniversalLink(signedOrder: signedOrder)

        print(url)

        XCTAssertEqual(testUrl, url)
    }

}