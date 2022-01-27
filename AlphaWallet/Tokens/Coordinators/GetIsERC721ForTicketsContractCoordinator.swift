// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import Result
import PromiseKit

class GetIsERC721ForTicketsContractCoordinator {
    private let server: RPCServer

    init(forServer server: RPCServer) {
        self.server = server
    }

    func getIsERC721ForTicketContract(for contract: AlphaWallet.Address) -> Promise<Bool> {
        return GetInterfaceSupported165Coordinator(forServer: server)
            .getInterfaceSupported165(hash: Constants.balances165Hash721Ticket, contract: contract)
    }
}
