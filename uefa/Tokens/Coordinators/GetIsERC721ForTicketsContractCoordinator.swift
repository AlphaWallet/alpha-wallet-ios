// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import Result

class GetIsERC721ForTicketsContractCoordinator {
    private let server: RPCServer

    init(forServer server: RPCServer) {
        self.server = server
    }

    func getIsERC721ForTicketContract(for contract: AlphaWallet.Address, completion: @escaping (Result<Bool, AnyError>) -> Void) {
        //TODO check ERC165 interface hash
        guard let defaultTicketContract = Uefa.Constants.ticketContractAddress else { return completion(.success(false)) }
        if contract.sameContract(as: defaultTicketContract) {
            completion(.success(true))
        } else {
            completion(.success(false))
        }
    }
}
