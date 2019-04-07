// Copyright © 2018 Stormbird PTE. LTD.

import XCTest
@testable import AlphaWallet

class ServersCoordinatorTests: XCTestCase {
    func testServerListIsComplete() {
        XCTAssertEqual(Set(ServersCoordinator.serversOrdered), Set(RPCServer.allCases))
    }
}
