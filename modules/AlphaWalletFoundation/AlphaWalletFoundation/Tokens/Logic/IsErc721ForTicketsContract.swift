// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import PromiseKit

public class IsErc721ForTicketsContract {
    private let server: RPCServer
    private lazy var resolver = IsInterfaceSupported165(forServer: server)

    public init(forServer server: RPCServer) {
        self.server = server
    }

    public func getIsERC721ForTicketContract(for contract: AlphaWallet.Address) -> Promise<Bool> {
        return resolver.getInterfaceSupported165(hash: Constants.balances165Hash721Ticket, contract: contract)
    }
}
