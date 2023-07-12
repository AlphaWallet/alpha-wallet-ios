// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress
import AlphaWalletABI
import BigInt

public struct FunctionCall {
    public struct Argument: CustomStringConvertible {
        public let type: ABIType
        public let value: Any?

        public init(type: ABIType, value: Any?) {
            self.type = type
            self.value = value
        }

        //NOTE: tuples are presented as array, the rest of types are able to be represented with `CustomStringConvertible` here we handle only array values
        // and single types, Maybe `.function` value also need to be handled
        public var description: String {
            if let value = value as? [Any] {
                let value = value.map { toString($0) }.joined(separator: ", ")
                return "[" + value + "]"
            } else {
                return toString(value)
            }
        }

        private func toString(_ value: Any?) -> String {
            if let value = value as? AlphaWallet.Address {
                return value.eip55String
            //We special-case Bool otherwise it will be printed as "1" below
            } else if type == .bool, let value = value as? Bool {
                return value.description
            } else if let value = value as? CustomStringConvertible {
                return value.description
            } else {
                return String()
            }
        }
    }
}

public struct DecodedFunctionCall {
    public enum FunctionType {
//NOTE: Not sure if we need these functions
//        case erc20TotalSupply
//        case erc20BalanceOf(address: AlphaWallet.Address)
//        case erc20Allowance(address: AlphaWallet.Address, address: AlphaWallet.Address)
//        case erc20TransferFrom(address: AlphaWallet.Address, address: AlphaWallet.Address, value: BigUInt)

        //NOTE: erc20
        case erc20Transfer(recipient: AlphaWallet.Address, value: BigUInt)
        case erc20Approve(spender: AlphaWallet.Address, value: BigUInt)
        case erc721ApproveAll(spender: AlphaWallet.Address, value: Bool)
        //NOTE: native crypto
        case nativeCryptoTransfer(value: BigUInt)
        //NOTE: erc1155
        case erc1155SafeTransfer(spender: AlphaWallet.Address)
        case erc1155SafeBatchTransfer(spender: AlphaWallet.Address)

        case others(name: String, arguments: [FunctionCall.Argument])
    }

    //TODO why not make these vars in enum case above?
    static let erc20Transfer = (name: "transfer", interfaceHash: "a9059cbb", byteCount: 68)
    static let erc20Approve = (name: "approve", interfaceHash: "095ea7b3", byteCount: 68)
    static let erc721ApproveAll = (name: "setApprovalForAll", interfaceHash: "a22cb465", byteCount: 68)
    static let erc1155SafeTransfer = (name: "safeTransferFrom", interfaceHash: "f242432a", byteCount: 68)
    static let erc1155SafeBatchTransfer = (name: "safeBatchTransferFrom", interfaceHash: "2eb2c2d6", byteCount: 68)

    public let name: String
    public let arguments: [FunctionCall.Argument]
    public let type: FunctionType

    public init?(data: Data) {
        if let decoded = DecodedFunctionCall.decode(data: data, abi: AlphaWallet.Ethereum.ABI.erc20) {
            self = decoded
        } else if let decoded = DecodedFunctionCall.decode(data: data, abi: AlphaWallet.Ethereum.ABI.erc721) {
            self = decoded
        } else {
            return nil
        }
    }

    public init(name: String, arguments: [FunctionCall.Argument], type: FunctionType) {
        self.name = name
        self.arguments = arguments
        self.type = type
    }

    public static func nativeCryptoTransfer(value: BigUInt) -> DecodedFunctionCall {
        .init(name: "Transfer", arguments: .init(), type: .nativeCryptoTransfer(value: value))
    }

    public init(name: String, arguments: [FunctionCall.Argument]) {
        self.name = name
        self.arguments = arguments
        self.type = DecodedFunctionCall.FunctionType(name: name, arguments: arguments)
    }
}
