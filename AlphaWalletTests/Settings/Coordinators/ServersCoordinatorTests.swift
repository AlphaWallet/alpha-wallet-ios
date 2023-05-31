// Copyright © 2018 Stormbird PTE. LTD.

@testable import AlphaWallet
import AlphaWalletFoundation
import XCTest

class ServersCoordinatorTests: XCTestCase {
    func testServerListIsComplete() {
        XCTAssertEqual(Set(ServersCoordinator.serversOrdered), Set(RPCServer.availableServers))
    }
}
