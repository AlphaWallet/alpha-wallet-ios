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
    func testLogLargeNftJsonFiles() async throws {
        let token = Token()
        guard let bundlePath = Bundle(for: AddressStorageTests.self).path(forResource: "base64_image_example", ofType: "txt") else { XCTFail(); return }
        let largeImage = try String(contentsOfFile: bundlePath)

        let uri = URL(string: "https://www.google.com/")!
        let asset_1 = NonFungibleBalance.NftAssetRawValue(json: largeImage, source: .uri(uri))
        let matches1 = await crashlytics.logLargeNftJsonFiles(for: [.update(token: token, field: .nonFungibleBalance(.assets([asset_1])))], fileSizeThreshold: 0.5)
        XCTAssertTrue(matches1)

        let asset_2 = NonFungibleBalance.NftAssetRawValue(json: "", source: .uri(uri))
        let matches2 = await crashlytics.logLargeNftJsonFiles(for: [.update(token: token, field: .nonFungibleBalance(.assets([asset_2])))], fileSizeThreshold: 0.5)
        XCTAssertFalse(matches2)
    }
}
// swiftlint:enable all
