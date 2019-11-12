// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit

//In the future, this can include invoking functions other than for sending of Ether and tokens
enum Eip681Type {
    case nativeCryptoSend(server: RPCServer?, recipient: AddressOrEnsName, amount: String)
    case erc20Send(contract: AlphaWallet.Address, server: RPCServer?, recipient: AddressOrEnsName, amount: String)
    case invalidOrNotSupported

    var parameters: (contract: AlphaWallet.Address, RPCServer?, recipient: AddressOrEnsName, amount: String)? {
        switch self {
        case .nativeCryptoSend(let server, let recipient, let amount):
            return (Constants.nativeCryptoAddressInDatabase, server, recipient, amount)
        case .erc20Send(let contract, let server, let recipient, let amount):
            return (contract, server, recipient, amount)
        case .invalidOrNotSupported:
            return nil
        }
    }
}

struct Eip681Parser {
    static let scheme = "ethereum"
    static let optionalPrefix = "pay-"

    private let protocolName: String
    private let address: AddressOrEnsName
    private let functionName: String?
    private let params: [String: String]

    init(protocolName: String, address: AddressOrEnsName, functionName: String?, params: [String: String]) {
        self.protocolName = protocolName
        self.address = address
        self.functionName = functionName
        self.params = params
    }

    //https://github.com/ethereum/EIPs/blob/master/EIPS/eip-681.md
    func parse() -> Promise<Eip681Type> {
        let chainId = params["chainId"].flatMap { Int($0) }
        if let recipient = params["address"].flatMap({ AddressOrEnsName(string: $0) }), functionName == "transfer", let contract = address.contract {
            let optionalAmountBigInt = params["uint256"].flatMap({ Double($0) }).flatMap({ BigInt($0) })
            let amount: String
            if let amountBigInt = optionalAmountBigInt {
                //TODO According to the EIP, check for UNITS (if available), and if that matches the symbol of the specified contract, use the decimals (if available) returned by the contract. Since we are also checking the decimals based on the contract, just make sure symbols (if it is provided) matches
                amount = amountBigInt.description
            } else {
                amount = ""
            }
            return .value(.erc20Send(contract: contract, server: chainId.flatMap { .init(chainID: $0) }, recipient: recipient, amount: amount))
        } else if functionName == nil {
            //TODO UNITS is either optional or "ETH" for native crypto sends. If it's not provided, we treat it as something like 3.14e18
            let amount: String
            if let value = params["value"], let amountToSend = Double(value) {
                amount = amountToSend.description
            } else {
                amount = ""
            }
            return .value(.nativeCryptoSend(server: chainId.flatMap { .init(chainID: $0) }, recipient: address, amount: amount))
        } else {
            return .value(.invalidOrNotSupported)
        }
    }

    static func stripOptionalPrefix(from string: String) -> String {
        guard string.hasPrefix(optionalPrefix) else { return string }
        return string.substring(from: optionalPrefix.count)
    }
}
