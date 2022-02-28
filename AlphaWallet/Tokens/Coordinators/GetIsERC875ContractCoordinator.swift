// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Result
import PromiseKit

class GetIsERC875ContractCoordinator {
    private let server: RPCServer

    init(forServer server: RPCServer) {
        self.server = server
    }

    func getIsERC875Contract(for contract: AlphaWallet.Address) -> Promise<Bool> {
        let function = GetIsERC875()
        return callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, timeout: Constants.fetchContractDataTimeout).map { dictionary -> Bool in
            if let isERC875 = dictionary["0"] as? Bool {
                return isERC875
            } else {
                throw AnyError(Web3Error(description: "Error extracting result from \(contract.eip55String).\(function.name)()"))
            }
        }
    }
}
