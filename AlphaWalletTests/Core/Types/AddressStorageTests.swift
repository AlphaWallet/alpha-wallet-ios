//
//  AddressStorageTests.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 03.06.2022.
//

import XCTest
import AlphaWalletAddress
import AlphaWalletCore
@testable import AlphaWallet
import AlphaWalletFoundation

private struct FakeTickerId: Codable {
    private enum CodingKeys: String, CodingKey {
        case platforms
    }

    let platforms: [String: AlphaWallet.Address]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        platforms = container.decode([String: String].self, forKey: .platforms, defaultValue: [:])
            .compactMapValues { AlphaWallet.Address(string: $0) }
    }
}

class AddressStorageTests: XCTestCase {

    func testInMemoryAddressStorage() throws {
//        return; //NOTE: disable this test as it takes too mutch time for execution
//
//        guard let bundlePath = Bundle(for: AddressStorageTests.self).path(forResource: "tikersForTest", ofType: "json") else { XCTFail() }
//        let jsonData = try Data(String(contentsOfFile: bundlePath).utf8)
//
//        self.measure {
//            let storage = InMemoryAddressStorage()
//            register(addressStorage: storage)
//
//            do {
//                _ = try JSONDecoder().decode([FakeTickerId].self, from: jsonData)
//            } catch {
//                XCTFail()
//            }
//
//            let storage2 = InMemoryAddressStorage()
//            register(addressStorage: storage2)
//
//            do {
//                _ = try JSONDecoder().decode([FakeTickerId].self, from: jsonData)
//            } catch {
//                XCTFail()
//            }
//        }
    }

    func testInFileAddressStorage() throws {
        let filestorage: StorageType = try FileStorage.forTestSuite()
        guard let bundlePath = Bundle(for: AddressStorageTests.self).path(forResource: "tikersForTest", ofType: "json") else { XCTFail(); return }
        let jsonData = try Data(String(contentsOfFile: bundlePath).utf8)

        self.measure {
            let storage: FileAddressStorage = FileAddressStorage(persistentStorage: filestorage)
            register(addressStorage: storage)

            do {
                _ = try JSONDecoder().decode([FakeTickerId].self, from: jsonData)
            } catch { XCTFail() }

            let storage2 = FileAddressStorage(persistentStorage: filestorage)
            register(addressStorage: storage2)

            do {
                _ = try JSONDecoder().decode([FakeTickerId].self, from: jsonData)
            } catch { XCTFail() }
        }
    }

}
