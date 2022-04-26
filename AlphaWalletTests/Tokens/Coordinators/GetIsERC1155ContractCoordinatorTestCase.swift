//
//  GetIsERC1155ContractCoordinatorTestCase.swift
//  AlphaWalletTests
//
//  Created by Jerome Chan on 14/4/22.
//

@testable import AlphaWallet
import AlphaWalletAddress
import PromiseKit
import XCTest

class GetIsERC1155ContractCoordinatorTestCase: XCTestCase {

    private let fileName = "test-cache.json"
    private let address1: AlphaWallet.Address = AlphaWallet.Address(string: "0xbbce83173d5c1d122ae64856b4af0d5ae07fa362")!
    private var result: Bool?

    override func setUpWithError() throws {
        let url = try cacheUrlFor(fileName: fileName)
        if FileManager.default.fileExists(atPath: url.path) && FileManager.default.isDeletableFile(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testgetIsERC1155Contract() throws {
        let coordinator = GetIsERC1155ContractCoordinator(forServer: .main, cacheName: fileName)
        let expectation = expectation(description: "Waiting for server response")
        firstly {
            coordinator.getIsERC1155Contract(for: address1)
        }.done { returnValue in
            self.result = returnValue
        }.ensure {
            expectation.fulfill()
        }.catch {error in
            XCTFail("Unknown error: \(error)")
        }
        wait(for: [expectation], timeout: 20)
        let cache = CachedERC1155ContractDictionary(fileName: fileName)
        XCTAssertNotNil(cache)
        XCTAssertNotNil(result)
        let cachedResult = cache?.isERC1155Contract(for: address1)
        XCTAssertNotNil(cachedResult)
        XCTAssertEqual(cachedResult, result)
        cache?.remove()
    }

}
