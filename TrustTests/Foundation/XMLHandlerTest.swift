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

    let tokenHex = "0x00000000000000000000000000000000fefe5ae99a3000000000000000010001".substring(from: 2)
    
    func testParser() {
        let fifaDetails = XMLHandler().getFifaInfoForTicket(
            tokenId: BigUInt(tokenHex, radix: 16)!, index: UInt16(1)
        )
        XCTAssertNotNil(fifaDetails)
        print(fifaDetails)
    }
    
}
