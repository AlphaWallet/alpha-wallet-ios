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
    private let server: RPCServer

    init(server: RPCServer) {
        self.server = server
    }

    public func hasEnoughAllowance(tokenAddress: AlphaWallet.Address, owner: AlphaWallet.Address, spender: AlphaWallet.Address, amount: BigUInt) -> Promise<(hasEnough: Bool, shortOf: BigUInt)> {
        if tokenAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) {
            return .value((true, 0))
        }

        return firstly {
            callSmartContract(withServer: server, contract: tokenAddress, functionName: "allowance", abiString: Web3.Utils.erc20ABI, parameters: [owner.eip55String, spender.eip55String] as [AnyObject])
        }.map { result -> (Bool, BigUInt) in
            guard let allowance = result["0"] as? BigUInt else {
                throw CastError.init(actualValue: result["0"], expectedType: BigUInt.self)
            }

            if allowance >= amount {
                return (true, 0)
            } else {
                return (false, amount - allowance)
            }
        }
    }
}
