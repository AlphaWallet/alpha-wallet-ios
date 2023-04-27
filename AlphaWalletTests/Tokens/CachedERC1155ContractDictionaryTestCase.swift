//
//  CachedERC1155ContractDictionaryTestCase.swift
//  AlphaWalletTests
//
//  Created by Jerome Chan on 13/4/22.
//

@testable import AlphaWallet
import AlphaWalletAddress
import XCTest
import AlphaWalletFoundation

class CachedERC1155ContractDictionaryTestCase: XCTestCase {

    private enum FileNames: String, CaseIterable {
        case hit = "testCacheHit.json"
        case miss = "testCacheMiss.json"
        case persists = "testCachePersists.json"
    }

    private let address1: AlphaWallet.Address = AlphaWallet.Address(string: "0xbbce83173d5c1d122ae64856b4af0d5ae07fa362")!
    private let address2: AlphaWallet.Address = AlphaWallet.Address(string: "0x829BD824B016326A401d083B33D092293333A830")!
    private let address3: AlphaWallet.Address = AlphaWallet.Address(string: "0xbDd147D953c400318bac7316519885688C3C9e07")!

    override func setUpWithError() throws {
        try FileNames.allCases.forEach {
            let url = try cacheUrlFor(fileName: $0.rawValue)
            if FileManager.default.fileExists(atPath: url.path) && FileManager.default.isDeletableFile(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
    }

    func testCacheHit() throws {
        let cache = CachedERC1155ContractDictionary(fileName: FileNames.hit.rawValue)!
        cache.setContract(for: address1, true)
        XCTAssertTrue(cache.isERC1155Contract(for: address1)!)
        cache.setContract(for: address1, false)
        XCTAssertFalse(cache.isERC1155Contract(for: address1)!)
        cache.setContract(for: address2, true)
        XCTAssertTrue(cache.isERC1155Contract(for: address2)!)
        cache.setContract(for: address2, false)
        XCTAssertFalse(cache.isERC1155Contract(for: address2)!)
        cache.remove()
    }

    func testCacheMiss() throws {
        let cache = CachedERC1155ContractDictionary(fileName: FileNames.miss.rawValue)!
        XCTAssertNil(cache.isERC1155Contract(for: address1))
        cache.remove()
    }

    func testCacheFilePersists() throws {
        let cache1 = CachedERC1155ContractDictionary(fileName: FileNames.persists.rawValue)!
        cache1.setContract(for: address1, true)
        cache1.setContract(for: address2, false)
        let url = try cacheUrlFor(fileName: FileNames.persists.rawValue)
        let result = FileManager.default.fileExists(atPath: url.path)
        XCTAssertTrue(result)
        let cache2 = CachedERC1155ContractDictionary(fileName: FileNames.persists.rawValue)!
        XCTAssertTrue(cache2.isERC1155Contract(for: address1)!)
        XCTAssertFalse(cache2.isERC1155Contract(for: address2)!)
        XCTAssertNil(cache2.isERC1155Contract(for: address3))
        cache1.remove()
        cache2.remove()
    }

}
