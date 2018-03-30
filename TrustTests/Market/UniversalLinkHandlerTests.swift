//
// Created by James Sangalli on 24/3/18.
//

import Foundation
@testable import Trust
import XCTest

class UniversalLinkHandlerTests: XCTestCase {

    func testUniversalLinkParser() {
        let testUrl = "https://app.awallet.io/AAGGoFq8Ule8mhAmpLxvC6i75IbR0J2lcys55AECAwQFBgcICYvWi5I+Tl5m9XumBD5jLIm6i39kD7F40UW4BaJDEVOWLTYz3kek7wjT7Bn+2w0NCiyx7zWuvseTA8qfoIqCIxob"
        let signedOrder = UniversalLinkHandler().parseURL(url: testUrl)
        XCTAssertGreaterThanOrEqual(signedOrder.signature.count, 130)
        //let url = UniversalLinkHandler.createUniversalLink(signedOrder: signedOrder)
        //print(url)
        //XCTAssertEqual(testUrl, url)
    }

}