//
// Created by James Sangalli on 20/11/19.
//

import Foundation
import PromiseKit

public class IsInterfaceSupported165 {
    private let server: RPCServer

    public init(forServer server: RPCServer) {
        self.server = server
    }

    public func getInterfaceSupported165(hash: String, contract: AlphaWallet.Address) -> Promise<Bool> {
        let function = GetInterfaceSupported165Encode()
        return firstly {
            callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [hash] as [AnyObject])
        }.map { result in
            if let supported = result["0"] as? Bool {
                return supported
            } else {
                throw createABIError(.invalidArgumentType)
            }
        }
    }
}
