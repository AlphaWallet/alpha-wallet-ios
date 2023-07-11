// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import BigInt

//TODO: In the future, this can include invoking functions other than for sending of Ether and tokens
//TODO: apply FungibleAmount instead of String
public enum Eip681Amount {
    case uint256(String, eNotation: Bool)
    case ether(String)

    public var rawValue: String {
        switch self {
        case .uint256(let string, _): return string
        case .ether(let string): return string
        }
    }
}
public enum Eip681Type {
    case nativeCryptoSend(server: RPCServer?, recipient: AddressOrDomainName, amount: Eip681Amount)
    case erc20Send(contract: AlphaWallet.Address, server: RPCServer?, recipient: AddressOrDomainName?, amount: Eip681Amount)
    case invalidOrNotSupported

    public var parameters: (contract: AlphaWallet.Address, RPCServer?, recipient: AddressOrDomainName?, amount: Eip681Amount)? {
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

public struct Eip681Parser {
    public static let scheme = "ethereum"
    public static let optionalPrefix = "pay-"

    private let protocolName: String
    private let address: AddressOrDomainName
    private let functionName: String?
    private let params: [String: String]

    public init(protocolName: String, address: AddressOrDomainName, functionName: String?, params: [String: String]) {
        self.protocolName = protocolName
        self.address = address
        self.functionName = functionName
        self.params = params
    }

    // NOTE: formatter for get rid of e notations
    private let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = .en_US
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false

        return formatter
    }()

    private let decimalParser = DecimalParser()

    //https://github.com/ethereum/EIPs/blob/master/EIPS/eip-681.md
    public func parse() -> Eip681Type {
        let chainId = params["chainId"].flatMap { Int($0) }
        if functionName == "transfer", let contract = address.contract {
            let recipient = params["address"].flatMap({ AddressOrDomainName(string: $0) })
            let optionalAmountBigInt = params["uint256"].flatMap { decimalParser.parseAnyDecimal(from: $0) }
            let amount: String
            let eNotation = params["uint256"].flatMap { $0.contains("e") } ?? false
            if let amountBigInt = optionalAmountBigInt {
                //TODO According to the EIP, check for UNITS (if available), and if that matches the symbol of the specified contract, use the decimals (if available) returned by the contract. Since we are also checking the decimals based on the contract, just make sure symbols (if it is provided) matches
                amount = formatter.string(double: amountBigInt.doubleValue) ?? String(amountBigInt.doubleValue)
            } else {
                amount = ""
            }
            return .erc20Send(contract: contract, server: chainId.flatMap { .init(chainID: $0) }, recipient: recipient, amount: .uint256(amount, eNotation: eNotation))
        } else if functionName == nil {
            //TODO UNITS is either optional or "ETH" for native crypto sends. If it's not provided, we treat it as something like 3.14e18, but it also can be like 1
            let amount: String
            if let value = params["value"], let amountToSend = decimalParser.parseAnyDecimal(from: value) {
                amount = formatter.string(double: amountToSend.doubleValue) ?? String(amountToSend.doubleValue)
            } else {
                amount = ""
            }
            return .nativeCryptoSend(server: chainId.flatMap { .init(chainID: $0) }, recipient: address, amount: .ether(amount))
        } else {
            return .invalidOrNotSupported
        }
    }

    public static func stripOptionalPrefix(from string: String) -> String {
        guard string.hasPrefix(optionalPrefix) else { return string }
        return string.substring(from: optionalPrefix.count)
    }
}
