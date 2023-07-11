//
//  ENSDelegateImpl.swift
//  AlphaWallet
//
//  Created by Hwee-Boon Yar on Apr/7/22.
//

import Foundation
import AlphaWalletENS
import AlphaWalletWeb3
import Combine

class ENSDelegateImpl: ENSDelegate {
    private let blockchainProvider: BlockchainProvider

    init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    func getInterfaceSupported165(chainId: Int, hash: String, contract: AlphaWallet.Address) -> AnyPublisher<Bool, AlphaWalletENS.SmartContractError> {
        return IsInterfaceSupported165(blockchainProvider: blockchainProvider)
            .getInterfaceSupported165(hash: hash, contract: contract)
            .mapError { e in SmartContractError.embedded(e) }
            .eraseToAnyPublisher()
    }

    func callSmartContract(withChainId chainId: ChainId, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject]) -> AnyPublisher<[String: Any], SmartContractError> {

        return blockchainProvider
            .call(AnyContractMethodCall(contract: contract, functionName: functionName, abiString: abiString, parameters: parameters))
            .mapError { e in SmartContractError.embedded(e) }
            .eraseToAnyPublisher()
    }

    func getSmartContractCallData(withChainId chainId: ChainId, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject]) -> Data? {
        do {
            return try AnyContractMethod(method: functionName, abi: abiString, params: parameters).encodedABI()
        } catch {
            return nil
        }
    }
}
