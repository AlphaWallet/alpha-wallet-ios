// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import Combine

public class IsErc721ForTicketsContract {
    private let blockchainProvider: BlockchainProvider
    private lazy var isInterfaceSupported165 = IsInterfaceSupported165(blockchainProvider: blockchainProvider)
    //UEFA 721 balances function hash
    static let balances165Hash721Ticket = "0xc84aae17"

    public init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    public func getIsErc721ForTicketContract(for contract: AlphaWallet.Address) async throws -> Bool {
        return try await isInterfaceSupported165.getInterfaceSupported165(hash: IsErc721ForTicketsContract.balances165Hash721Ticket, contract: contract)
    }
}
