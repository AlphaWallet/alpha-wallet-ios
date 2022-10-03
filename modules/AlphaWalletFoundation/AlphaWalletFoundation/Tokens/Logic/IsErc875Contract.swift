// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit

public class IsErc875Contract {
    private let server: RPCServer

    public init(forServer server: RPCServer) {
        self.server = server
    }

    public func getIsERC875Contract(for contract: AlphaWallet.Address) -> Promise<Bool> {
        let function = GetIsERC875()
        return callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi)
            .map { dictionary -> Bool in
                guard let isERC875 = dictionary["0"] as? Bool else {
                    throw CastError(actualValue: dictionary["0"], expectedType: Bool.self)
                }
                return isERC875
            }
    }
}
