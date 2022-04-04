// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import web3swift

typealias EthereumAddress_fromWeb3SwiftPod = EthereumAddress
extension EthereumAddress_fromWeb3SwiftPod: CustomStringConvertible {
    public var description: String {
        return address
    }
}

struct FunctionCall {
    struct Argument: CustomStringConvertible {
        let type: ABIType
        let value: Any?

        //NOTE: tuples are presented as array, the rest of types are able to be represented with `CustomStringConvertible` here we handle only array values
        // and single types, Maybe `.function` value also need to be handled
        var description: String {
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
            } else if let value = value as? CustomStringConvertible {
                return value.description
            } else {
                return String()
            }
        }
    }
}

struct DecodedFunctionCall {
    enum FunctionType {
//NOTE: Not sure if we need these functions
//        case erc20TotalSupply
//        case erc20BalanceOf(address: AlphaWallet.Address)
//        case erc20Allowance(address: AlphaWallet.Address, address: AlphaWallet.Address)
//        case erc20TransferFrom(address: AlphaWallet.Address, address: AlphaWallet.Address, value: BigUInt)

        //NOTE: erc20
        case erc20Transfer(recipient: AlphaWallet.Address, value: BigUInt)
        case erc20Approve(spender: AlphaWallet.Address, value: BigUInt)
        //NOTE: native crypty
        case nativeCryptoTransfer(value: BigUInt)
        //NOTE: erc1155
        case erc1155SafeTransfer(spender: AlphaWallet.Address)
        case erc1155SafeBatchTransfer(spender: AlphaWallet.Address)

        case others(name: String, arguments: [FunctionCall.Argument])
    }

    static let erc20Transfer = (name: "transfer", interfaceHash: "a9059cbb", byteCount: 68)
    static let erc20Approve = (name: "approve", interfaceHash: "095ea7b3", byteCount: 68)
    static let erc1155SafeTransfer = (name: "safeTransferFrom", interfaceHash: "f242432a", byteCount: 68)
    static let erc1155SafeBatchTransfer = (name: "safeBatchTransferFrom", interfaceHash: "2eb2c2d6", byteCount: 68)

    let name: String
    let arguments: [FunctionCall.Argument]
    let type: FunctionType

    init?(data: Data) {
        guard let decoded = DecodedFunctionCall.decode(data: data, abi: AlphaWallet.Ethereum.ABI.ERC20) else { return nil }
        self = decoded
    }

    init(name: String, arguments: [FunctionCall.Argument], type: FunctionType) {
        self.name = name
        self.arguments = arguments
        self.type = type
    }

    static func nativeCryptoTransfer(value: BigUInt) -> DecodedFunctionCall {
        .init(name: "Transfer", arguments: .init(), type: .nativeCryptoTransfer(value: value))
    }

    init(name: String, arguments: [FunctionCall.Argument]) {
        self.name = name
        self.arguments = arguments
        self.type = DecodedFunctionCall.FunctionType(name: name, arguments: arguments)
    }
}
