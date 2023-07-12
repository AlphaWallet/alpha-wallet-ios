//
//  Erc721GetBalancesMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation
import AlphaWalletABI
import AlphaWalletAddress
import BigInt

public struct Erc721GetBalancesMethodCall: ContractMethodCall {
    public typealias Response = [String]

    private let address: AlphaWallet.Address

    public let contract: AlphaWallet.Address
    public var name: String { "getBalances" }
    public var abi: String { AlphaWallet.Ethereum.ABI.erc721 }
    public var parameters: [AnyObject] { [address.eip55String] as [AnyObject] }

    public init(contract: AlphaWallet.Address, address: AlphaWallet.Address) {
        self.address = address
        self.contract = contract
    }

    public func response(from dictionary: [String: Any]) throws -> [String] {
        return Erc721GetBalancesMethodCall.adapt(dictionary["0"])
    }

    private static func adapt(_ values: Any?) -> [String] {
        guard let array = values as? [BigUInt] else { return [] }
        return array.filter({ $0 != BigUInt(0) }).map { each in
            let value = each.serialize().hex()
            return "0x\(value)"
        }
    }
}
