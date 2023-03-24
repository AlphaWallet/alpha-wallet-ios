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

class ENSDelegateImpl: ENSDelegate {
    private let blockchainProvider: BlockchainProvider
    private let supported165: IsInterfaceSupported165

    init(blockchainProvider: BlockchainProvider) {
        self.supported165 = IsInterfaceSupported165(blockchainProvider: blockchainProvider)
        self.blockchainProvider = blockchainProvider
    }

    func getInterfaceSupported165(chainId: Int, hash: String, contract: AlphaWallet.Address) -> AnyPublisher<Bool, AlphaWalletENS.SmartContractError> {
        return Future { [supported165] in try await supported165.getInterfaceSupported165(hash: hash, contract: contract) }
            .mapError { e in SmartContractError.embeded(e) }
            .eraseToAnyPublisher()
    }

    func callSmartContract(withChainId chainId: ChainId, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject]) -> AnyPublisher<[String: Any], SmartContractError> {

        return Future { [blockchainProvider] in
            try await blockchainProvider.call(AnyContractMethodCall(contract: contract, functionName: functionName, abiString: abiString, parameters: parameters))
        }.mapError { e in SmartContractError.embeded(e) }
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
