//
//  WebImageUrlTests.swift
//  AlphaWalletCoreTests
//
//  Created by Vladyslav Shepitko on 02.03.2022.
//

import XCTest
import AlphaWalletCore

class WebImageUrlTests: XCTestCase {

    func testWebImageUrls() {
        let u1 = WebImageURL(string: "https://lh3.googleusercontent.com/g-NFUWjS4IGgym8PHBxyhg5-G_B4x-IHgPKRkxo00JQFE3LOd-95yU2uhrokITVmV7KHEav6OMfAhfJ4roC5hwP-0tI9dMRd9wQLdw=s120")
        XCTAssertNotNil(u1?.googleContentSizeIfAvailable)
        XCTAssertEqual(u1?.googleContentSizeIfAvailable, GoogleContentSize.s750)
        XCTAssertNotNil(u1)

        let u11 = WebImageURL(string: "https://lh3.googleusercontent.com/g-NFUWjS4IGgym8PHBxyhg5-G_B4x-IHgPKRkxo00JQFE3LOd-95yU2uhrokITVmV7KHEav6OMfAhfJ4roC5hwP-0tI9dMRd9wQLdw=s120-c")
        XCTAssertNotNil(u11?.googleContentSizeIfAvailable)
        XCTAssertEqual(u11?.googleContentSizeIfAvailable, GoogleContentSize.s750)
        XCTAssertNotNil(u11)

        let u2 = WebImageURL(string: "https://lh3.googleusercontent.com/wOcdC7XRZ5JZ3Z5xym5jEi895YGuZKzrDxRLaxHPXWBPxH8fzXs9_7oml8mka4Suj2xp-yAu4q9Qp3-vx5aiWCbh-WCyu2pybUUEIQ=s120", rewriteGoogleContentSizeUrl: .s250)
        XCTAssertNotNil(u2?.googleContentSizeIfAvailable)
        XCTAssertEqual(u2?.googleContentSizeIfAvailable, GoogleContentSize.s250)
        XCTAssertNotNil(u2)

        let u22 = WebImageURL(string: "https://lh3.googleusercontent.com/wOcdC7XRZ5JZ3Z5xym5jEi895YGuZKzrDxRLaxHPXWBPxH8fzXs9_7oml8mka4Suj2xp-yAu4q9Qp3-vx5aiWCbh-WCyu2pybUUEIQ=s120", withUrlRewriting: false, rewriteGoogleContentSizeUrl: .s250)
        XCTAssertNil(u22?.googleContentSizeIfAvailable)

        let u3 = WebImageURL(string: "https://d32ju6eqdh546d.cloudfront.net/rivermengift/石质兽首蛇.png")
        XCTAssertNil(u3)

        let u4 = WebImageURL(string: "https://gateway.pinata.cloud/ipfs/QmXp1KjrTtR9oVNZxhKjzMFXWtgoyTM6ZJyFEXodzgEZQ1/263.png")
        XCTAssertNotNil(u4)

        let u5 = WebImageURL(string: "https://storage.opensea.io/files/9f7d57faea1308f84bd5d680b6f05e3a.svg")
        XCTAssertNotNil(u5)
    }

}
