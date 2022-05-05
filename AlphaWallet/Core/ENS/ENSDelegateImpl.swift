//
//  ENSDelegateImpl.swift
//  AlphaWallet
//
//  Created by Hwee-Boon Yar on Apr/7/22.
//

import Foundation
import AlphaWalletENS
import PromiseKit

fileprivate let globalCallSmartContract = callSmartContract
fileprivate let globalGetSmartContractCallData = getSmartContractCallData

protocol ENSDelegateImpl: ENSDelegate {
}

extension ENSDelegateImpl {
    func callSmartContract(withChainId chainId: ChainId, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject], timeout: TimeInterval?) -> Promise<[String: Any]> {
        let server = RPCServer(chainID: chainId)
        return globalCallSmartContract(server, contract, functionName, abiString, parameters, timeout, false, nil)
    }

    func getSmartContractCallData(withChainId chainId: ChainId, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject], timeout: TimeInterval?) -> Data? {
        let server = RPCServer(chainID: chainId)
        return globalGetSmartContractCallData(server, contract, functionName, abiString, parameters, timeout)
    }

    func getInterfaceSupported165(chainId: Int, hash: String, contract: AlphaWallet.Address) -> Promise<Bool> {
        let server = RPCServer(chainID: chainId)
        return IsInterfaceSupported165(forServer: server).getInterfaceSupported165(hash: hash, contract: contract)
    }
}
