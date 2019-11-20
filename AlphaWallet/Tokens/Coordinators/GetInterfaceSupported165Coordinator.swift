//
// Created by James Sangalli on 20/11/19.
//

import Foundation
import Result

class GetInterfaceSupported165Coordinator {
    private let server: RPCServer

    init(forServer server: RPCServer) {
        self.server = server
    }

    func getInterfaceSupported165(
            hash: String,
            contract: AlphaWallet.Address,
            completion: @escaping (Result<Bool, AnyError>) -> Void
    ) {
        let function = GetInterfaceSupported165Encode()
        callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [hash] as [AnyObject]).done { result in
            if let supported = result["0"] as? Bool {
                completion(.success(supported))
            } else {
                completion(.failure(AnyError(ABIError.invalidArgumentType)))
            }
        }.catch {
            completion(.failure(AnyError($0)))
        }
    }
}