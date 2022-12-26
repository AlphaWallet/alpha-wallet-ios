//
//  GetErc20Allowance.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 08.11.2022.
//

import Foundation
import BigInt
import PromiseKit
import AlphaWalletWeb3

class GetErc20Allowance {
    private let blockchainProvider: BlockchainProvider

    public init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    public func hasEnoughAllowance(tokenAddress: AlphaWallet.Address, owner: AlphaWallet.Address, spender: AlphaWallet.Address, amount: BigUInt) -> Promise<(hasEnough: Bool, shortOf: BigUInt)> {
        if tokenAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) {
            return .value((true, 0))
        }

        return firstly {
            blockchainProvider
                .callPromise(Erc20AllowanceRequest(contract: tokenAddress, owner: owner, spender: spender))
                .get {
                    print("xxx.Erc20 allowance value: \($0)")
                }.recover { e -> Promise<BigUInt> in
                    print("xxx.Erc20 allowance failure: \(e)")
                    throw e
                }
        }.map { allowance -> (Bool, BigUInt) in
            if allowance >= amount {
                return (true, 0)
            } else {
                return (false, amount - allowance)
            }
        }
    }
}

struct Erc20AllowanceRequest: ContractMethodCall {
    typealias Response = BigUInt

    let owner: AlphaWallet.Address
    let spender: AlphaWallet.Address
    let contract: AlphaWallet.Address
    let name: String = "allowance"
    let abi: String = Web3.Utils.erc20ABI
    var parameters: [AnyObject] { [owner.eip55String, spender.eip55String] as [AnyObject] }

    init(contract: AlphaWallet.Address, owner: AlphaWallet.Address, spender: AlphaWallet.Address) {
        self.contract = contract
        self.owner = owner
        self.spender = spender
    }

    func response(from resultObject: Any) throws -> BigUInt {
        guard let dictionary = resultObject as? [String: AnyObject] else {
            throw CastError(actualValue: resultObject, expectedType: [String: AnyObject].self)
        }

        guard let allowance = dictionary["0"] as? BigUInt else {
            throw CastError.init(actualValue: dictionary["0"], expectedType: BigUInt.self)
        }

        return allowance
    }
}
