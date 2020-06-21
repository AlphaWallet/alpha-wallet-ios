// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import Result

class GetIsERC721ForTicketsContractCoordinator {
    private let server: RPCServer

    init(forServer server: RPCServer) {
        self.server = server
    }

    func getIsERC721ForTicketContract(for contract: AlphaWallet.Address, completion: @escaping (Result<Bool, AnyError>) -> Void) {
        GetInterfaceSupported165Coordinator(forServer: server).getInterfaceSupported165(hash: Constants.balances165Hash721Ticket, contract: contract) { result in
            if let value = result.value {
                completion(.success(value))
            } else {
                completion(.success(false))
            }
        }
    }
}
