//
// Created by James Sangalli on 24/3/18.
//

import Foundation
@testable import Trust
import XCTest

class UniversalLinkHandlerTests: XCTestCase {

    func testUniversalLinkParser() {
        let signedOrder: SignedOrder = UniversalLinkHandler.parseURL(url:
        "https://www.awallet.io/AA9CQFq1tAAAe+6CvdnoZrK9EUeApH8iYcaE4wECAwQFBgcICS+YK4TGNZZ6m2MG7VeJp8" +
                "GRkWQXHjfczfS1m+VHVEEFMIGLiWt9JA9WxZ698gkGLuVNp6NZCQVzlnTc/c7PPpsb"
        )

        print(signedOrder.signature)
        XCTAssertGreaterThanOrEqual(signedOrder.signature.count, 130)
    }

}