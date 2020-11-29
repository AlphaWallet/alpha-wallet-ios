// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import TrustKeystore

struct DecodedFunctionCall {
    enum FunctionType {
        case erc20Transfer(recipient: AlphaWallet.Address, value: BigUInt)
        case nativeCryptoTransfer(value: BigUInt)
        case others
    }

    static let erc20Transfer = (name: "transfer", interfaceHash: "a9059cbb", byteCount: 68)

    let name: String
    let arguments: [(type: ABIType, value: AnyObject)]
    let type: FunctionType

    private static func decode(data: Data) -> DecodedFunctionCall? {
        //TODO Better to be provided as ABI. Including computing the hash from: transfer(address,uint256)
        if data.count == erc20Transfer.byteCount && data[0..<4].hex() == erc20Transfer.interfaceHash, let value = BigUInt(data[(4 + 32)..<(4 + 32 + 32)].hex(), radix: 16) {
            //Compiler thinks it's a `Slice<Data>` if don't explicitly state the type, so we have to split into 2 `if`s
            let recipientData: Data = data[4..<(4 + 32)][4 + 12..<(4 + 32)]
            if let recipient = AlphaWallet.Address(string: recipientData.hexEncoded) {
                return DecodedFunctionCall(name: erc20Transfer.name, arguments: [(type: .address, value: Address(address: recipient) as AnyObject), (type: .uint(bits: 256), value: value as AnyObject)], type: .erc20Transfer(recipient: recipient, value: value))
            }
        }
        return nil
    }

    init?(data: Data) {
        guard let decoded = DecodedFunctionCall.decode(data: data) else { return nil }
        self = decoded
    }

    private init(name: String, arguments: [(type: ABIType, value: AnyObject)], type: FunctionType) {
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
        //TODO Better to be provided as ABI. Including computing the hash from: transfer(address,uint256)
        if name == DecodedFunctionCall.erc20Transfer.name && arguments.count == 2 && arguments[0].type == .address && arguments[1].type == .uint(bits: 256), let address = arguments[0].value as? Address, let value = arguments[1].value as? BigUInt {
            self.type = .erc20Transfer(recipient: AlphaWallet.Address(address: address), value: value)
        } else {
            self.type = .others
        }
    }
}