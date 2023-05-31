// Copyright © 2022 Stormbird PTE. LTD.

@testable import AlphaWalletFoundation
import Combine
import XCTest

class FileTokenEntriesProviderTests: XCTestCase {
    func testLoadLocalJsonFile() {
        var cancellables = Set<AnyCancellable>()
        let expectation = self.expectation(description: "Wait for publisher")
        FileTokenEntriesProvider().tokenEntries()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { value in
                    XCTAssertFalse(value.isEmpty)
                    expectation.fulfill()
                }
            ).store(in: &cancellables)

        wait(for: [expectation], timeout: 0.1)
    }
}