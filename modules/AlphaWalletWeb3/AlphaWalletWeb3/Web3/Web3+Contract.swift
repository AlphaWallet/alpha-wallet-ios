
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
        var contract: ContractProtocol
        let web3: Web3
        public var options: Web3Options? = nil
        
        public init?(web3: Web3, abiString: String, at: EthereumAddress? = nil, options: Web3Options? = nil, abiVersion: Int = 2) {
            self.web3 = web3
            self.options = web3.options
            switch abiVersion {
            case 1:
                guard let c = ContractV1(abiString, at: at) else { return nil }
                contract = c
            case 2:
                guard let c = ContractV2(abiString, at: at) else { return nil }
                contract = c
            default:
                return nil
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
            transaction.chainID = self.web3.chainID

            return TransactionIntermediate(transaction: transaction, web3: self.web3, contract: self.contract, method: "fallback", options: mergedOptions)
        }
        
        public func method(_ method:String = "fallback", parameters: [AnyObject] = [], extraData: Data = Data(), options: Web3Options?) -> TransactionIntermediate? {
            let mergedOptions = Web3Options.merge(self.options, with: options)
            guard var transaction = contract.method(method, parameters: parameters, extraData: extraData, options: mergedOptions) else { return nil }
            transaction.chainID = web3.chainID

            return TransactionIntermediate(transaction: transaction, web3: self.web3, contract: self.contract, method: method, options: mergedOptions)
        }

        public func parseEvent(_ eventLog: EventLog) -> (eventName: String?, eventData: [String:Any]?) {
            return self.contract.parseEvent(eventLog)
        }
        
        public func createEventParser(_ eventName:String, filter:EventFilter?) -> EventParserProtocol? {
            return EventParser(web3: self.web3, eventName: eventName, contract: self.contract, filter: filter)
        }
    }
}
