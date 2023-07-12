//
//  Erc1155BalanceOfBatchMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation
import AlphaWalletABI
import AlphaWalletAddress
import AlphaWalletCore
import BigInt

public struct Erc1155BalanceOfBatchMethodCall: ContractMethodCall {
    public typealias Response = [BigInt: BigUInt]

    private let tokenIds: Set<BigInt>
    private let address: AlphaWallet.Address

    public let contract: AlphaWallet.Address
    public let name: String = "balanceOfBatch"
    public let abi: String = AlphaWallet.Ethereum.ABI.erc1155
    public var parameters: [AnyObject] {
        let address = EthereumAddress(address.eip55String)!
        let addresses: [EthereumAddress] = [EthereumAddress](repeating: address, count: tokenIds.count)
        return [addresses, Array(tokenIds)] as [AnyObject]
    }

    public init(contract: AlphaWallet.Address, address: AlphaWallet.Address, tokenIds: Set<BigInt>) {
        self.contract = contract
        self.address = address
        self.tokenIds = tokenIds
    }

    public func response(from dictionary: [String: Any]) throws -> [BigInt: BigUInt] {
        guard let balances = dictionary["0"] as? [BigUInt], balances.count == tokenIds.count else {
            throw CastError(actualValue: dictionary["0"], expectedType: [BigUInt].self)
        }

        return Dictionary(uniqueKeysWithValues: zip(tokenIds, balances))
    }
}
