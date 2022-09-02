// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import PromiseKit

public class IsErc721ForTicketsContract {
    private let server: RPCServer

    public init(forServer server: RPCServer) {
        self.server = server
    }

    public func getIsERC721ForTicketContract(for contract: AlphaWallet.Address) -> Promise<Bool> {
        return IsInterfaceSupported165(forServer: server)
            .getInterfaceSupported165(hash: Constants.balances165Hash721Ticket, contract: contract)
    }
}
