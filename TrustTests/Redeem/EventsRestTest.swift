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

class EventsRestTest: XCTestCase {

    var expectations = [XCTestExpectation]()

    func testEventsRest() {
        let expectation = self.expectation(description: "wait til callback")
        expectations.append(expectation)
        let address = Address(string: "")
        EventsRest().getEvents { result in
            switch result {
            case .success(let events):
                print(events)
                expectation.fulfill()
            case .failure(let error):
                print(error)
            }
        }
        wait(for: expectations, timeout: 10)
    }

}
