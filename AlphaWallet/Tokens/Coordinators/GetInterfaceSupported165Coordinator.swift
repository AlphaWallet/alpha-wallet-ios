//
// Created by James Sangalli on 20/11/19.
//

import Foundation
import PromiseKit
import Result

class GetInterfaceSupported165Coordinator {
    private let server: RPCServer

    init(forServer server: RPCServer) {
        self.server = server
    }

    func getInterfaceSupported165(
            hash: String,
            contract: AlphaWallet.Address,
            completion: @escaping (ResultResult<Bool, AnyError>.t) -> Void
    ) {
        let function = GetInterfaceSupported165Encode()
        callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [hash] as [AnyObject], timeout: TokensDataStore.fetchContractDataTimeout).done { result in
            if let supported = result["0"] as? Bool {
                completion(.success(supported))
            } else {
                completion(.failure(AnyError(ABIError.invalidArgumentType)))
            }
        }.catch {
            completion(.failure(AnyError($0)))
        }
    }

    func getInterfaceSupported165(hash: String, contract: AlphaWallet.Address) -> Promise<Bool> {
        let function = GetInterfaceSupported165Encode()
        return firstly {
            callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [hash] as [AnyObject], timeout: TokensDataStore.fetchContractDataTimeout)
        }.map { result in
            if let supported = result["0"] as? Bool {
                return supported
            } else {
                throw AnyError(ABIError.invalidArgumentType)
            }
        }
    }
}