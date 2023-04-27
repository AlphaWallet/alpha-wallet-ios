//
//  FeaturesTestCase.swift
//  AlphaWalletTests
//
//  Created by Jerome Chan on 25/4/22.
//

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class FeaturesTestCase: XCTestCase {

    let fileName = "FeaturesTestCase.json"

    override func setUpWithError() throws {
        let url = try documentUrlFor(fileName: fileName)
        if FileManager.default.fileExists(atPath: url.path) && FileManager.default.isDeletableFile(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    func testCreate() throws {
        let features = Features(fileName: fileName)!
        features.setAvailable(.isAlertsEnabled, true)
        let url = try documentUrlFor(fileName: fileName)
        let result = FileManager.default.fileExists(atPath: url.path)
        XCTAssertTrue(result)
    }

    func testReadAndWrite() throws {
        var features = Features(fileName: fileName)!
        features.setAvailable(.isAlertsEnabled, true)
        features.setAvailable(.is24SeedWordPhraseAllowed, false)
        features = Features(fileName: fileName)!
        XCTAssertTrue(features.isAvailable(.isAlertsEnabled))
        XCTAssertFalse(features.isAvailable(.is24SeedWordPhraseAllowed))
    }

    func testDefaultValues() throws {
        let features = Features(fileName: fileName)!
        XCTAssertEqual(features.isAvailable(.isActivityEnabled), FeaturesAvailable.isActivityEnabled.defaultValue)
    }
}
