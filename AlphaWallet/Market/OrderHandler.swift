// Copyright © 2018 Stormbird PTE. LTD.

import BigInt
import TrustWalletCore

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
	var hexa2Bytes: [UInt8] {
		let hexa: [Character]
		if count % 2 == 0 {
			hexa = Array(self)
		} else {
			hexa = Array(("0" + self))
		}
		return stride(from: 0, to: count, by: 2).compactMap {
			UInt8(String(hexa[$0..<$0.advanced(by: 2)]), radix: 16)
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

    private let keyStore = try! EtherKeystore()

    func signOrders(orders: [Order], account: EthereumAccount) throws -> [SignedOrder] {
        var signedOrders = [SignedOrder]()
        var messages = [Data]()

        for order in orders {
            let message: [UInt8] = encodeMessageForTrade(
                    price: order.price,
                    expiryBuffer: order.expiry,
                    tokens: order.indices,
                    contractAddress: order.contractAddress
            )
            messages.append(Data(bytes: message))
        }

        let signatures = try! keyStore.signMessageBulk(messages, for: account).dematerialize()
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
            tokens: [UInt16],
            contractAddress: AlphaWallet.Address
    ) -> [UInt8] {
        let arrayLength: Int = 84 + tokens.count * 2
        var buffer = [UInt8]()
        buffer.reserveCapacity(arrayLength)
        let priceInWei = UniversalLinkHandler.padTo32(Array(price.serialize()))
        let expiry = UniversalLinkHandler.padTo32(Array(expiryBuffer.serialize()))
        buffer.append(contentsOf: priceInWei)
        buffer.append(contentsOf: expiry)
        //no leading zeros issue here
        buffer.append(contentsOf: contractAddress.eip55String.hexa2Bytes)
        let tokensUint8 = OrderHandler.uInt16ArrayToUInt8(arrayOfUInt16: tokens)
        buffer.append(contentsOf: tokensUint8)
        return buffer
    }

    public static func uInt16ArrayToUInt8(arrayOfUInt16: [UInt16]) -> [UInt8] {
        var arrayOfUint8 = [UInt8]()
        for i in 0..<arrayOfUInt16.count {
            var UInt8ArrayPair = arrayOfUInt16[i].bigEndian.data.array
            arrayOfUint8.append(UInt8ArrayPair[0])
            arrayOfUint8.append(UInt8ArrayPair[1])
        }
        return arrayOfUint8
    }

}
