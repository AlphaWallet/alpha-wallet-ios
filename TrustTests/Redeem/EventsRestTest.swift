//
//  EventsRestTest.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/11/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
@testable import Trust
import XCTest
import BigInt

class EventsRestTest: XCTestCase {

    var expectations = [XCTestExpectation]()

    func testEventsRest() {
        let expectation = self.expectation(description: "wait til callback")
        expectations.append(expectation)
        EventsRest().getEvents { result in
            print(result)
            expectation.fulfill()
        }
        wait(for: expectations, timeout: 10)
    }

}
