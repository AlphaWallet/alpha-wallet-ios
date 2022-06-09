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
        return; //NOTE: disable this test as it takes too mutch time for execution

        guard let bundlePath = Bundle(for: AddressStorageTests.self).path(forResource: "tikersForTest", ofType: "json") else { XCTFail(); return }
        guard let jsonData = try String(contentsOfFile: bundlePath).data(using: .utf8) else { XCTFail(); return }

        self.measure {
            let storage = InMemoryAddressStorage()
            register(addressStorage: storage)

            do {
                let decodedTokenEntries = try JSONDecoder().decode([FakeTickerId].self, from: jsonData)
                print(decodedTokenEntries.count)
            } catch {
                XCTFail()
            }

            let storage2 = InMemoryAddressStorage()
            register(addressStorage: storage2)

            do {
                let decodedTokenEntries = try JSONDecoder().decode([FakeTickerId].self, from: jsonData)
                print(decodedTokenEntries.count)
            } catch {
                XCTFail()
            }
        }
    }

    func testInFileAddressStorage() throws {
        let filestorage: StorageType = try FileStorage.forTestSuite()
        guard let bundlePath = Bundle(for: AddressStorageTests.self).path(forResource: "tikersForTest", ofType: "json") else { XCTFail(); return }
        guard let jsonData = try String(contentsOfFile: bundlePath).data(using: .utf8) else { XCTFail(); return }

        self.measure {
            let storage: FileAddressStorage = FileAddressStorage(persistentStorage: filestorage)
            register(addressStorage: storage)

            do {
                let decodedTokenEntries = try JSONDecoder().decode([FakeTickerId].self, from: jsonData)
                print(decodedTokenEntries.count)
            } catch { XCTFail() }

            let storage2 = FileAddressStorage(persistentStorage: filestorage)
            register(addressStorage: storage2)

            do {
                let decodedTokenEntries = try JSONDecoder().decode([FakeTickerId].self, from: jsonData)
                print(decodedTokenEntries.count)
            } catch { XCTFail() }
        }
    }

}
