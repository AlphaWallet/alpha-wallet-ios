//
// Created by James Sangalli on 24/3/18.
//

import Foundation
@testable import Trust
import XCTest

class UniversalLinkHandlerTests: XCTestCase {

    func testUniversalLinkParser() {
        let testUrl = "https://app.awallet.io/AA9CQAAAAAC8mhAmpLxvC6i75IbR0J2lcys55IDwAoKWhOr6d7KY+8hNPvg7BADzHG9wEdp+nfFuaoeZzZ5PskIO9ym+0j0VxiTh6uyb7et3F/Y2HcgvcqNTA0xZ1gE="
//                "https://app.awallet.io/AA9CQFq1tAAAe+6CvdnoZrK9EUeApH8iYcaE4wECAwQFBgcICS+YK4TGNZZ6m2MG7V" +
//                "eJp8GRkWQXHjfczfS1m+VHVEEFMIGLiWt9JA9WxZ698gkGLuVNp6NZCQVzlnTc/c7PPpsb"
        let signedOrder = UniversalLinkHandler.parseURL(url: testUrl)
        XCTAssertGreaterThanOrEqual(signedOrder.signature.count, 130)
        //let url = UniversalLinkHandler.createUniversalLink(signedOrder: signedOrder)
        //print(url)
        //XCTAssertEqual(testUrl, url)
    }

}