//
// Created by James Sangalli on 24/3/18.
//

import Foundation
@testable import Trust
import XCTest

class UniversalLinkHandlerTests: XCTestCase {

    func testUniversalLinkParser() {
        let testUrl = "https://app.awallet.io/AA9CQFq1tAAAe+6CvdnoZrK9EUeApH8iYcaE4wECAwQFBgcICS+YK4TGNZZ6m2MG7VeJp8GRkWQXHjfczfS1m+VHVEEFMIGLiWt9JA9WxZ698gkGLuVNp6NZCQVzlnTc/c7PPpsb"
        let signedOrder = UniversalLinkHandler.parseURL(url: testUrl)
        XCTAssertGreaterThanOrEqual(signedOrder.signature.count, 130)
        //let url = UniversalLinkHandler.createUniversalLink(signedOrder: signedOrder)
        //print(url)
        //XCTAssertEqual(testUrl, url)
    }

}