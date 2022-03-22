// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit

enum Erc20 {
    static func hasEnoughAllowance(server: RPCServer, tokenAddress: AlphaWallet.Address, owner: AlphaWallet.Address, spender: AlphaWallet.Address, amount: BigUInt) -> Promise<(hasEnough: Bool, shortOf: BigUInt)> {
        NSLog("xxx hasEnoughAllowance(\(tokenAddress.eip55String)) wallet: \(owner.eip55String) spender: \(spender.eip55String)…")
        if tokenAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) {
            NSLog("xxx skipping check allowance since native crypto")
            return .value((true, 0))
        }

        let abi = String(data: AlphaWallet.Ethereum.ABI.ERC20, encoding: .utf8)!
        return firstly {
            callSmartContract(withServer: server, contract: tokenAddress, functionName: "allowance", abiString: abi, parameters: [owner.eip55String, spender.eip55String] as [AnyObject], timeout: Constants.fetchContractDataTimeout)
        }.map { allowanceResult -> (Bool, BigUInt) in
            //hhh remove
            print("xxx before")
            print(allowanceResult)
            print("xxx after")

            if let allowance = allowanceResult["0"] as? BigUInt {
                NSLog("xxx allowance: \(allowance) needed: \(amount) enough? \(allowance >= amount)")
                let hasEnough = allowance >= amount
                if hasEnough {
                    return (true, 0)
                } else {
                    return (false, amount - allowance)
                }
            } else {
                NSLog("xxx can't convert allowance from: \(allowanceResult)")
                //TODO maybe error is better than triggered a prompt for approval
                return (false, amount)
            }
        }
    }

    static func buildApproveTransaction(keystore: Keystore, token: AlphaWallet.Address, server: RPCServer, owner: AlphaWallet.Address, spender: AlphaWallet.Address, amount: BigUInt) -> (UnconfirmedTransaction, TransactionConfirmationConfiguration) {
        let configuration: TransactionConfirmationConfiguration = .approve(keystore: keystore)
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