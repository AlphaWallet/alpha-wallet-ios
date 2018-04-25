//
//  XMLHandlerTest.swift
//  AlphaWalletTests
//
//  Created by James Sangalli on 11/4/18.
//

import Foundation
import XCTest
@testable import Trust
import BigInt

class XMLHandlerTest: XCTestCase {

    let tokenHex = "0x0a015af6d74042544e43484e0101000200000000000000000000000000000000".substring(from: 2)
    
    func testParser() {
        let fifaDetails = XMLHandler().getFifaInfoForTicket(
            tokenId: BigUInt(tokenHex, radix: 16)!, index: UInt16(1)
        )
        XCTAssertNotNil(fifaDetails)
    }
    
}
