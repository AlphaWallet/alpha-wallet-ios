// Copyright © 2018 Stormbird PTE. LTD.

import BigInt
import WalletCore

public struct Order {
    var price: BigUInt
    var indices: [UInt16]
    var expiry: BigUInt
    var contractAddress: AlphaWallet.Address
    var count: BigUInt
    var nonce: BigUInt
    var tokenIds: [BigUInt]?
    var spawnable: Bool
    var nativeCurrencyDrop: Bool
}

public struct SignedOrder {
    var order: Order
    var message: [UInt8]
    var signature: String
}

extension String {
	var hexToBytes: [UInt8] {
		let hex: [Character]
		if count % 2 == 0 {
			hex = Array(self)
		} else {
			hex = Array(("0" + self))
		}
		return stride(from: 0, to: count, by: 2).compactMap {
			UInt8(String(hex[$0..<$0.advanced(by: 2)]), radix: 16)
		}
	}
}

extension BinaryInteger {
    var data: Data {
        var source = self
        return Data(bytes: &source, count: MemoryLayout<Self>.size)
    }
}

extension Data {
    var array: [UInt8] {
        return Array(self)
    }
}

public class OrderHandler {
    private let keystore: EtherKeystore

    init(keystore: EtherKeystore) {
        self.keystore = keystore
    }

    func signOrders(orders: [Order], account: AlphaWallet.Address, tokenType: TokenType) throws -> [SignedOrder] {
        let messages = createMessagesFromOrders(orders: orders, tokenType: tokenType)
        return try! bulkSignOrders(messages: messages, account: account, orders: orders)
    }

    private func createMessagesFromOrders(orders: [Order], tokenType: TokenType) -> [Data] {
        var messages = [Data]()
        switch tokenType {
        case .erc721ForTickets:
            for order in orders {
                let message: [UInt8] = encodeMessageForTrade(
                        price: order.price,
                        expiryBuffer: order.expiry,
                        tokenIds: order.tokenIds ?? [BigUInt](),
                        contractAddress: order.contractAddress
                )
                messages.append(Data(bytes: message))
            }
        case .erc875:
            for order in orders {
                let message: [UInt8] = encodeMessageForTrade(
                        price: order.price,
                        expiryBuffer: order.expiry,
                        indices: order.indices,
                        contractAddress: order.contractAddress
                )
                messages.append(Data(bytes: message))
            }
        case .erc721, .nativeCryptocurrency, .erc20:
            break
        }
        return messages
    }

    private func bulkSignOrders(messages: [Data], account: AlphaWallet.Address, orders: [Order]) throws -> [SignedOrder] {
        var signedOrders = [SignedOrder]()
        let signatures = try! keystore.signMessageBulk(messages, for: account).dematerialize()
        for i in 0..<signatures.count {
            let signedOrder = SignedOrder(
                    order: orders[i],
                    message: messages[i].bytes,
                    signature: signatures[i].hexString
            )
            signedOrders.append(signedOrder)
        }
        return signedOrders
    }

    func encodeMessageForTrade(
            price: BigUInt,
            expiryBuffer: BigUInt,
            indices: [UInt16],
            contractAddress: AlphaWallet.Address
    ) -> [UInt8] {
        let arrayLength: Int = 84 + indices.count * 2
        var buffer = [UInt8]()
        buffer.reserveCapacity(arrayLength)
        let priceInWei = UniversalLinkHandler.padTo32(Array(price.serialize()))
        let expiry = UniversalLinkHandler.padTo32(Array(expiryBuffer.serialize()))
        buffer.append(contentsOf: priceInWei)
        buffer.append(contentsOf: expiry)
        //no leading zeros issue here
        buffer.append(contentsOf: contractAddress.eip55String.hexToBytes)
        let tokensUint8 = OrderHandler.uInt16ArrayToUInt8(arrayOfUInt16: indices)
        buffer.append(contentsOf: tokensUint8)
        return buffer
    }

    func encodeMessageForTrade(
            price: BigUInt,
            expiryBuffer: BigUInt,
            tokenIds: [BigUInt],
            contractAddress: AlphaWallet.Address
    ) -> [UInt8] {
        let arrayLength: Int = 84 + tokenIds.count * 32
        var buffer = [UInt8]()
        buffer.reserveCapacity(arrayLength)
        let priceInWei = Array(price.serialize())
        let expiry = Array(expiryBuffer.serialize())
        buffer.append(contentsOf: UniversalLinkHandler.padTo32(priceInWei))
        buffer.append(contentsOf: UniversalLinkHandler.padTo32(expiry))
        buffer.append(contentsOf: contractAddress.eip55String.hexToBytes)
        for token in tokenIds {
            buffer.append(contentsOf: UniversalLinkHandler.padTo32(token.serialize().array))
        }
        return buffer
    }

    public static func uInt16ArrayToUInt8(arrayOfUInt16: [UInt16]) -> [UInt8] {
        var arrayOfUint8 = [UInt8]()
        for i in 0..<arrayOfUInt16.count {
            let UInt8ArrayPair = arrayOfUInt16[i].bigEndian.data.array
            arrayOfUint8.append(UInt8ArrayPair[0])
            arrayOfUint8.append(UInt8ArrayPair[1])
        }
        return arrayOfUint8
    }

}
