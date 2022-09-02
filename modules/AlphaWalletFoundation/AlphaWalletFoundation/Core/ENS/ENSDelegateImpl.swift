//
//  ENSDelegateImpl.swift
//  AlphaWallet
//
//  Created by Hwee-Boon Yar on Apr/7/22.
//

import Foundation
import AlphaWalletENS
import PromiseKit
import Combine

fileprivate let globalCallSmartContract = callSmartContract
fileprivate let globalGetSmartContractCallData = getSmartContractCallData

protocol ENSDelegateImpl: ENSDelegate {
}

extension ENSDelegateImpl {
    public func callSmartContract(withChainId chainId: ChainId, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject]) -> AnyPublisher<[String: Any], SmartContractError> {
        let server = RPCServer(chainID: chainId)
        return globalCallSmartContract(server, contract, functionName, abiString, parameters, false, nil).publisher
            .mapError { e in SmartContractError.embeded(e) }
            .share()
            .eraseToAnyPublisher()
    }

    public func getSmartContractCallData(withChainId chainId: ChainId, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject]) -> Data? {
        let server = RPCServer(chainID: chainId)
        return globalGetSmartContractCallData(server, contract, functionName, abiString, parameters)
    }

    public func getInterfaceSupported165(chainId: Int, hash: String, contract: AlphaWallet.Address) -> AnyPublisher<Bool, SmartContractError> {
        let server = RPCServer(chainID: chainId)
        return IsInterfaceSupported165(forServer: server).getInterfaceSupported165(hash: hash, contract: contract).publisher
            .mapError { e in SmartContractError.embeded(e) }
            .share()
            .eraseToAnyPublisher()
    }
}
