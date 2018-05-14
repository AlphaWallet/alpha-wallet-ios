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

    let tokenHex = "0x20b5b23fea00bd9860b43e604000000000000000000000000000000000000".substring(from: 2)
    
    func testParser() {
        let fifaDetails = XMLHandler().getFifaInfoForTicket(
            tokenId: BigUInt(tokenHex, radix: 16)!, index: UInt16(1)
        )
        XCTAssertNotNil(fifaDetails)
        print(fifaDetails)
    }
    
}
