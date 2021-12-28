// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import TrustKeystore
import web3swift

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

        case others
    }

    static let erc20Transfer = (name: "transfer", interfaceHash: "a9059cbb", byteCount: 68)
    static let erc20Approve = (name: "approve", interfaceHash: "095ea7b3", byteCount: 68)
    static let erc1155SafeTransfer = (name: "safeTransferFrom", interfaceHash: "f242432a", byteCount: 68)
    static let erc1155SafeBatchTransfer = (name: "safeBatchTransferFrom", interfaceHash: "2eb2c2d6", byteCount: 68)

    let name: String
    let arguments: [(type: ABIType, value: AnyObject)]
    let type: FunctionType

    init?(data: Data) {
        guard let decoded = DecodedFunctionCall.decode(data: data, abi: AlphaWallet.Ethereum.ABI.ERC20) else { return nil }
        self = decoded
    }

    init(name: String, arguments: [(type: ABIType, value: AnyObject)], type: FunctionType) {
        self.name = name
        self.arguments = arguments
        self.type = type
    }

    static func nativeCryptoTransfer(value: BigUInt) -> DecodedFunctionCall {
        .init(name: "Transfer", arguments: .init(), type: .nativeCryptoTransfer(value: value))
    }

    init(name: String, arguments: [(type: ABIType, value: AnyObject)]) {
        self.name = name
        self.arguments = arguments
        self.type = DecodedFunctionCall.FunctionType(name: name, arguments: arguments)
    }
}
