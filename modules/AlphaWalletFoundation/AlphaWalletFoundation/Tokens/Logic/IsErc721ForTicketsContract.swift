// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import PromiseKit

public class IsErc721ForTicketsContract {
    private let server: RPCServer
    private lazy var isInterfaceSupported165 = IsInterfaceSupported165(forServer: server)
    //UEFA 721 balances function hash
    static let balances165Hash721Ticket = "0xc84aae17"

    public init(forServer server: RPCServer) {
        self.server = server
    }

    public func getIsErc721ForTicketContract(for contract: AlphaWallet.Address) -> Promise<Bool> {
        return isInterfaceSupported165.getInterfaceSupported165(hash: IsErc721ForTicketsContract.balances165Hash721Ticket, contract: contract)
    }
}
