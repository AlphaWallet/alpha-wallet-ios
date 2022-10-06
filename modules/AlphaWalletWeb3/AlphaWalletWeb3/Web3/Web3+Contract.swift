//  Web3+ContractV1.swift
//  web3swift
//
//  Created by Alexander Vlasov on 19.12.2017.
//  Copyright © 2017 Bankex Foundation. All rights reserved.
//

import Foundation 
import BigInt

extension Web3 {
    
    public class Contract {
        public enum Version {
            case v1
            case v2
        }

        var contract: ContractProtocol
        let web3: Web3
        public var options: Web3Options?
        
        public init?(web3: Web3, abiString: String, at: EthereumAddress? = nil, options: Web3Options? = nil, version: Version = .v2) {
            self.web3 = web3
            self.options = web3.options
            switch version {
            case .v1:
                guard let contract = ContractV1(abi: abiString, address: at) else { return nil }
                self.contract = contract
            case .v2:
                guard let contract = ContractV2(abi: abiString, address: at) else { return nil }
                self.contract = contract
            }
            var mergedOptions = Web3Options.merge(self.options, with: options)
            if at != nil {
                contract.address = at
                mergedOptions?.to = at
            } else if let addr = mergedOptions?.to {
                contract.address = addr
            }
            self.options = mergedOptions
        }
        
        public func deploy(bytecode: Data, parameters: [AnyObject] = [], extraData: Data = Data(), options: Web3Options?) -> TransactionIntermediate? {
            let mergedOptions = Web3Options.merge(self.options, with: options)
            guard var transaction = contract.deploy(bytecode: bytecode, parameters: parameters, extraData: extraData, options: mergedOptions) else { return nil }
            transaction.chainID = web3.chainID

            return TransactionIntermediate(transaction: transaction, web3: web3, contract: contract, method: "fallback", options: mergedOptions)
        }
        
        public func method(_ method: String = "fallback", parameters: [AnyObject] = [], extraData: Data = Data(), options: Web3Options?) -> TransactionIntermediate? {
            let mergedOptions = Web3Options.merge(self.options, with: options)
            guard var transaction = contract.method(method, parameters: parameters, extraData: extraData, options: mergedOptions) else { return nil }
            transaction.chainID = web3.chainID

            return TransactionIntermediate(transaction: transaction, web3: web3, contract: contract, method: method, options: mergedOptions)
        }

        public func parseEvent(_ eventLog: EventLog) -> (eventName: String?, eventData: [String: Any]?) {
            return contract.parseEvent(eventLog)
        }
        
        public func createEventParser(_ eventName: String, filter: EventFilter?) -> EventParserProtocol? {
            return EventParser(web3: web3, eventName: eventName, contract: contract, filter: filter)
        }
    }
}
