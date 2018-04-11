//
//  XMLHandlerTest.swift
//  AlphaWalletTests
//
//  Created by James Sangalli on 11/4/18.
//

import Foundation
import XCTest
@testable import Trust

class XMLHandlerTest: XCTestCase {
    
    func testParser() {
        let fifaDetails = XMLHandler().getFifaInfoForToken(
            tokenId: "0x0a015af6d74042544e43484e01010001",
            lang: "en"
        )
        XCTAssertNotNil(fifaDetails)
    }
    
}
