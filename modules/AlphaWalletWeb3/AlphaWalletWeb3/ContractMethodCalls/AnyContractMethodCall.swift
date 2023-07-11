//
//  AnyContractMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation
import AlphaWalletAddress

public struct AnyContractMethodCall: ContractMethodCall {
    public typealias Response = [String: Any]

    public let contract: AlphaWallet.Address
    public let name: String
    public let abi: String
    public let parameters: [AnyObject]

    public init(contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject]) {
        self.contract = contract
        self.name = functionName
        self.abi = abiString
        self.parameters = parameters
    }

    public func response(from dictionary: [String: Any]) throws -> [String: Any] {
        return dictionary
    }
}
