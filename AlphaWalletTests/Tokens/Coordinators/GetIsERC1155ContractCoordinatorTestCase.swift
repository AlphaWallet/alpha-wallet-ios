//
//  IsErc1155ContractTestCase.swift
//  AlphaWalletTests
//
//  Created by Jerome Chan on 14/4/22.
//

@testable import AlphaWallet
import AlphaWalletAddress
import XCTest
import AlphaWalletFoundation

//class IsErc1155ContractTestCase: XCTestCase {
//
//    private let fileName = "test-cache.json"
//    private let address1: AlphaWallet.Address = AlphaWallet.Address(string: "0xbbce83173d5c1d122ae64856b4af0d5ae07fa362")!
//    private var result: Bool?
//
//    override func setUpWithError() throws {
//        let url = try cacheUrlFor(fileName: fileName)
//        if FileManager.default.fileExists(atPath: url.path) && FileManager.default.isDeletableFile(atPath: url.path) {
//            try FileManager.default.removeItem(at: url)
//        }
//    }
//
//    func testgetIsErc1155Contract() throws {
//        let coordinator = IsErc1155Contract(forServer: .main, cacheName: fileName)
//        let expectation = expectation(description: "Waiting for server response")
//        firstly {
//            coordinator.getIsErc1155Contract(for: address1)
//        }.done { returnValue in
//            self.result = returnValue
//        }.ensure {
//            expectation.fulfill()
//        }.catch {error in
//            XCTFail("Unknown error: \(error)")
//        }
//        wait(for: [expectation], timeout: 20)
//        let cache = CachedERC1155ContractDictionary(fileName: fileName)
//        XCTAssertNotNil(cache)
//        XCTAssertNotNil(result)
//        let cachedResult = cache?.isERC1155Contract(for: address1)
//        XCTAssertNotNil(cachedResult)
//        XCTAssertEqual(cachedResult, result)
//        cache?.remove()
//    }
//
//}
