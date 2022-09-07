// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit

public enum Erc20 {
    public static func hasEnoughAllowance(server: RPCServer, tokenAddress: AlphaWallet.Address, owner: AlphaWallet.Address, spender: AlphaWallet.Address, amount: BigUInt) -> Promise<(hasEnough: Bool, shortOf: BigUInt)> {
        if tokenAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) {
            return .value((true, 0))
        }

        let abi = String(data: AlphaWallet.Ethereum.ABI.erc20, encoding: .utf8)!
        return firstly {
            callSmartContract(withServer: server, contract: tokenAddress, functionName: "allowance", abiString: abi, parameters: [owner.eip55String, spender.eip55String] as [AnyObject])
        }.map { allowanceResult -> (Bool, BigUInt) in
            if let allowance = allowanceResult["0"] as? BigUInt {
                let hasEnough = allowance >= amount
                if hasEnough {
                    return (true, 0)
                } else {
                    return (false, amount - allowance)
                }
            } else {
                //TODO maybe error is better than triggered a prompt for approval
                return (false, amount)
            }
        }
    }

    public static func buildApproveTransaction(keystore: Keystore, token: AlphaWallet.Address, server: RPCServer, owner: AlphaWallet.Address, spender: AlphaWallet.Address, amount: BigUInt) -> (UnconfirmedTransaction, TransactionType.Configuration) {
        let configuration: TransactionType.Configuration = .approve
        let transactionType: TransactionType = .prebuilt(server)
        //TODO should just provide a function name and be able to get the signature from the ABI in ERC20.json
        let function = Function(name: "approve", parameters: [ABIType.address, ABIType.uint(bits: 256)])
        //Note: be careful here with the BigUInt and BigInt, the type needs to be exact
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [spender, amount])
        let data = encoder.data
        let transaction: UnconfirmedTransaction = .init(transactionType: transactionType, value: 0, recipient: owner, contract: token, data: data)
        return (transaction, configuration)
    }
}
