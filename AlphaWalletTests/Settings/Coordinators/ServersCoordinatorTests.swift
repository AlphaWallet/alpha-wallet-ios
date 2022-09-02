// Copyright © 2018 Stormbird PTE. LTD.

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class ServersCoordinatorTests: XCTestCase {
    func testServerListIsComplete() {
        XCTAssertEqual(Set(ServersCoordinator.serversOrdered), Set(RPCServer.availableServers))
    }
}
