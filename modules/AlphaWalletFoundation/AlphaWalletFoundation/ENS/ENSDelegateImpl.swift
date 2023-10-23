//
//  ENSDelegateImpl.swift
//  AlphaWallet
//
//  Created by Hwee-Boon Yar on Apr/7/22.
//

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletENS
import AlphaWalletWeb3

class ENSDelegateImpl: ENSDelegate {
    private let blockchainProvider: BlockchainProvider

    init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    func getInterfaceSupported165Async(server: RPCServer, hash: String, contract: AlphaWallet.Address) async throws -> Bool {
        return try await IsInterfaceSupported165(blockchainProvider: blockchainProvider).getInterfaceSupported165(hash: hash, contract: contract)
    }

    func callSmartContract(withServer server: RPCServer, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject]) -> AnyPublisher<[String: Any], SmartContractError> {
        return blockchainProvider
            .call(AnyContractMethodCall(contract: contract, functionName: functionName, abiString: abiString, parameters: parameters))
            .mapError { e in SmartContractError.embedded(e) }
            .eraseToAnyPublisher()
    }

    func getSmartContractCallData(withServer server: RPCServer, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject]) -> Data? {
        do {
            return try AnyContractMethod(method: functionName, abi: abiString, params: parameters).encodedABI()
        } catch {
            return nil
        }
    }
}
