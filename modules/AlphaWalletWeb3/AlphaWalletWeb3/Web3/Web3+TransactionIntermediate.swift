//
//  Web3+TransactionIntermediate.swift
//  web3swift-iOS
//
//  Created by Alexander Vlasov on 26.02.2018.
//  Copyright © 2018 Bankex Foundation. All rights reserved.
//

import Foundation
import BigInt
import PromiseKit

extension Web3.Contract {

    public class TransactionIntermediate {
        public var transaction: EthereumTransaction
        public var contract: ContractProtocol
        public var method: String
        public var options: Web3Options? = Web3Options.defaultOptions()
        let web3: Web3

        public init (transaction: EthereumTransaction, web3: Web3, contract: ContractProtocol, method: String, options: Web3Options?) {
            self.transaction = transaction
            self.web3 = web3
            self.contract = contract
            self.contract.options = options
            self.method = method
            self.options = Web3Options.merge(web3.options, with: options)
            self.transaction.chainID = self.web3.chainID
        }
    }
}

extension Web3.Contract.TransactionIntermediate {

    func assemblePromise(options: Web3Options? = nil, onBlock: String = "pending") -> Promise<EthereumTransaction> {
        var assembledTransaction : EthereumTransaction = self.transaction
        let queue = self.web3.queue

        let eth = Web3.Eth(web3: self.web3)

        let returnPromise = Promise<EthereumTransaction> { seal in
            guard let mergedOptions = Web3Options.merge(self.options, with: options) else {
                seal.reject(Web3Error.inputError("Provided options are invalid"))
                return
            }
            guard let from = mergedOptions.from else {
                seal.reject(Web3Error.inputError("No 'from' field provided"))
                return
            }
            var optionsForGasEstimation = Web3Options()
            optionsForGasEstimation.from = mergedOptions.from
            optionsForGasEstimation.to = mergedOptions.to
            optionsForGasEstimation.value = mergedOptions.value
            let getNoncePromise : Promise<BigUInt> = eth.getTransactionCountPromise(address: from, onBlock: onBlock)
            let gasEstimatePromise : Promise<BigUInt> = eth.estimateGasPromise(assembledTransaction, options: optionsForGasEstimation, onBlock: onBlock)
            let gasPricePromise : Promise<BigUInt> = eth.getGasPricePromise()
            var promisesToFulfill: [Promise<BigUInt>] = [getNoncePromise, gasPricePromise, gasPricePromise]
            when(resolved: getNoncePromise, gasEstimatePromise, gasPricePromise).map(on: queue, { (results:[Result<BigUInt>]) throws -> EthereumTransaction in

                promisesToFulfill.removeAll()
                guard case .fulfilled(let nonce) = results[0] else {
                    throw Web3Error.inputError("Failed to fetch nonce")
                }
                guard case .fulfilled(let gasEstimate) = results[1] else {
                    throw Web3Error.inputError("Failed to fetch gas estimate")
                }
                guard case .fulfilled(let gasPrice) = results[2] else {
                    throw Web3Error.inputError("Failed to fetch gas price")
                }
                guard let estimate = Web3Options.smartMergeGasLimit(originalOptions: options, extraOptions: nil, gasEstimage: gasEstimate) else {
                    throw Web3Error.inputError("Failed to calculate gas estimate that satisfied options")
                }
                assembledTransaction.nonce = nonce
                assembledTransaction.gasLimit = estimate
                if assembledTransaction.gasPrice == 0 {
                    assembledTransaction.gasPrice = gasPrice
                }
                return assembledTransaction
            }).done(on: queue) {tx in
                    seal.fulfill(tx)
                }.catch(on: queue) {err in
                    seal.reject(err)
            }
        }
        return returnPromise
    }

    public func callPromise(options: Web3Options? = nil, onBlock: String = "latest") -> Promise<[String: Any]>{
        let eth = Web3.Eth(web3: self.web3)
        guard let mergedOptions = Web3Options.merge(self.options, with: options) else {
            return .init(error: Web3Error.inputError("Provided options are invalid"))
        }

        var optionsForCall = Web3Options()
        optionsForCall.from = mergedOptions.from
        optionsForCall.to = mergedOptions.to
        optionsForCall.value = mergedOptions.value
        optionsForCall.excludeZeroGasPrice = mergedOptions.excludeZeroGasPrice

        let callPromise: Promise<Data> = eth.callPromise(transaction, options: optionsForCall, onBlock: onBlock)

        return callPromise.map(on: web3.queue) { [method, contract] data in
            if method == "fallback" {
                let resultHex = data.toHexString().addHexPrefix()
                return ["result": resultHex as Any]
            }
            guard let decodedData = contract.decodeReturnData(method, data: data) else {
                throw Web3Error.inputError("Can not decode returned parameters")
            }

            return decodedData
        }
    }

    func estimateGasPromise(options: Web3Options? = nil, onBlock: String = "latest") -> Promise<BigUInt> {
        let eth = Web3.Eth(web3: self.web3)
        guard let mergedOptions = Web3Options.merge(self.options, with: options) else {
            return .init(error: Web3Error.inputError("Provided options are invalid"))
        }
        var optionsForGasEstimation = Web3Options()
        optionsForGasEstimation.from = mergedOptions.from
        optionsForGasEstimation.to = mergedOptions.to
        optionsForGasEstimation.value = mergedOptions.value

        return eth.estimateGasPromise(transaction, options: optionsForGasEstimation, onBlock: onBlock)
    }
}
