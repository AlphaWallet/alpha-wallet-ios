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
    private let sessionsProvider: SessionsProvider
    
    init(sessionsProvider: SessionsProvider) {
        self.sessionsProvider = sessionsProvider
    }

    func getInterfaceSupported165(chainId: Int, hash: String, contract: AlphaWallet.Address) -> AnyPublisher<Bool, AlphaWalletENS.SmartContractError> {
        guard let session = sessionsProvider.activeSessions.first(where: { $0.key.chainID == chainId }) else {
            return .empty()
        }

        return IsInterfaceSupported165(blockchainProvider: session.value.blockchainProvider)
            .getInterfaceSupported165(hash: hash, contract: contract)
            .publisher
            .mapError { e in SmartContractError.embeded(e) }
            .share()
            .eraseToAnyPublisher()
    }

    func callSmartContract(withChainId chainId: ChainId, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject]) -> AnyPublisher<[String: Any], SmartContractError> {
        guard let session = sessionsProvider.activeSessions.first(where: { $0.key.chainID == chainId })?.value else {
            return .empty()
        }

        return session
            .blockchainProvider
            .callPublisher(AnyContractMethodCallRequest(contract: contract, functionName: functionName, abiString: abiString, parameters: parameters))
            .mapError { e in SmartContractError.embeded(e) }
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

struct AnyContractMethodCallRequest: ContractMethodCall {
    typealias Response = [String: Any]

    let contract: AlphaWallet.Address
    let name: String
    let abi: String
    let parameters: [AnyObject]

    init(contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject]) {
        self.contract = contract
        self.name = functionName
        self.abi = abiString
        self.parameters = parameters
    }

    func response(from resultObject: Any) throws -> [String: Any] {
        guard let dictionary = resultObject as? [String: Any] else {
            throw CastError(actualValue: resultObject, expectedType: [String: AnyObject].self)
        }

        return dictionary
    }
}
