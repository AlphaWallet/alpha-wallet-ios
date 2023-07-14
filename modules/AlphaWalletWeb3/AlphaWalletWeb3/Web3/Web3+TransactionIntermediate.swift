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
        var transaction: Transaction
        var contract: ContractRepresentable
        var method: String
        var options: Web3Options? = Web3Options.defaultOptions()
        let web3: Web3

        public var data: Data {
            transaction.data
        }

        init(transaction: Transaction, web3: Web3, contract: ContractRepresentable, method: String, options: Web3Options?) {
            self.transaction = transaction
            self.web3 = web3
            self.contract = contract
            self.method = method
            self.options = Web3Options.merge(web3.options, with: options)
            self.transaction.chainID = self.web3.chainID
        }
    }
}

extension Web3.Contract.TransactionIntermediate {

    func assemblePromise(options: Web3Options? = nil, onBlock: String = "pending") -> Promise<Transaction> {
        var assembledTransaction = self.transaction

        let eth = Web3.Eth(web3: web3)

        let mergedOptions = Web3Options.merge(self.options, with: options)
        guard let from = mergedOptions.from else {
            return .init(error: Web3Error.inputError("No 'from' field provided"))
        }
        var optionsForGasEstimation = Web3Options()
        optionsForGasEstimation.from = mergedOptions.from
        optionsForGasEstimation.to = mergedOptions.to
        optionsForGasEstimation.value = mergedOptions.value

        let getNoncePromise: Promise<BigUInt> = eth.getTransactionCountPromise(address: from, onBlock: onBlock)
        let gasEstimatePromise: Promise<BigUInt> = eth.estimateGasPromise(assembledTransaction, options: optionsForGasEstimation, onBlock: onBlock)
        let gasPricePromise: Promise<BigUInt> = eth.getGasPricePromise()

        return when(resolved: getNoncePromise, gasEstimatePromise, gasPricePromise).map(on: web3.queue, { results throws -> Transaction in

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
        })
    }

    public func callPromise(options: Web3Options? = nil, onBlock: String = "latest") -> Promise<[String: Any]> {
        let eth = Web3.Eth(web3: self.web3)
        let mergedOptions = Web3Options.merge(self.options, with: options)
        var optionsForCall = Web3Options()
        optionsForCall.from = mergedOptions.from
        optionsForCall.to = mergedOptions.to
        optionsForCall.value = mergedOptions.value
        optionsForCall.excludeZeroGasPrice = mergedOptions.excludeZeroGasPrice

        return eth.callPromise(transaction, options: optionsForCall, onBlock: onBlock).map(on: web3.queue) { [method, contract] data in
            guard let decodedData = contract.decodeReturnData(method, data: data) else {
                throw Web3Error.inputError("Can not decode returned parameters")
            }

            return decodedData
        }
    }

    func estimateGasPromise(options: Web3Options? = nil, onBlock: String = "latest") -> Promise<BigUInt> {
        let eth = Web3.Eth(web3: self.web3)
        let mergedOptions = Web3Options.merge(self.options, with: options)
        var optionsForGasEstimation = Web3Options()
        optionsForGasEstimation.from = mergedOptions.from
        optionsForGasEstimation.to = mergedOptions.to
        optionsForGasEstimation.value = mergedOptions.value

        return eth.estimateGasPromise(transaction, options: optionsForGasEstimation, onBlock: onBlock)
    }
}
