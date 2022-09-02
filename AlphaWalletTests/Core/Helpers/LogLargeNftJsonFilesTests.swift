//
//  LogLargeNftJsonFilesTests.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 21.06.2022.
//

@testable import AlphaWallet
import XCTest
import AlphaWalletFoundation

// swiftlint:disable all
class LogLargeNftJsonFilesTests: XCTestCase {

    func testLogLargeNftJsonFiles() throws {
        let token = Token()
        guard let bundlePath = Bundle(for: AddressStorageTests.self).path(forResource: "base64_image_example", ofType: "txt") else { XCTFail(); return }
        let largeImage = try String(contentsOfFile: bundlePath)

        let uri = URL(string: "https://www.google.com/")!
        let asset_1 = NonFungibleBalance.NftAssetRawValue(json: largeImage, source: .uri(uri))
        XCTAssertTrue(crashlytics.logLargeNftJsonFiles(for: [.update(token: token, action: .nonFungibleBalance(.assets([asset_1])))], fileSizeThreshold: 0.5))

        let asset_2 = NonFungibleBalance.NftAssetRawValue(json: "", source: .uri(uri))
        XCTAssertFalse(crashlytics.logLargeNftJsonFiles(for: [.update(token: token, action: .nonFungibleBalance(.assets([asset_2])))], fileSizeThreshold: 0.5))
    }
}
// swiftlint:enable all
