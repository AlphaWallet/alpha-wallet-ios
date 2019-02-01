// Copyright © 2018 Stormbird PTE. LTD.

import BigInt
import TrustKeystore

public struct Order {
    var price: BigUInt
    var indices: [UInt16]
    var expiry: BigUInt
    var contractAddress: String
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
		let hexa: Array<Character>
		if count % 2 == 0 {
			hexa = Array(characters)
		} else {
			hexa = Array(("0" + self).characters)
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

    func signOrders(orders: [Order], account: Account) throws -> [SignedOrder] {
        var signedOrders = [SignedOrder]()
        var messages = [Data]()

        for i in 0...orders.count - 1 {
            let message: [UInt8] = encodeMessageForTrade(
                    price: orders[i].price,
                    expiryBuffer: orders[i].expiry,
                    tokens: orders[i].indices,
                    contractAddress: orders[i].contractAddress
            )
            messages.append(Data(bytes: message))
        }

        let signatures = try! keyStore.signMessageBulk(messages, for: account).dematerialize()

        for i in 0...signatures.count - 1 {
            let signedOrder = SignedOrder(
                    order: orders[i],
                    message: messages[i].bytes,
                    signature: signatures[i].hexString
            )
            signedOrders.append(signedOrder)
        }
        return signedOrders
    }

    //buffer size is 84 + tokens
    //first 32 bytes is allocated for price
    //next 32 for expiry
    //20 for contract address
    //remaining for tokens
    func encodeMessageForTrade(price: BigUInt,
                               expiryBuffer: BigUInt,
                               tokens: [UInt16],
                               contractAddress: String) -> [UInt8] {
        //token count * 2 because it is 16 bits not 8
        let arrayLength: Int = 84 + tokens.count * 2
        var buffer = [UInt8]()
        buffer.reserveCapacity(arrayLength)

        var priceInWei = Array(price.serialize())
        var expiry = Array(expiryBuffer.serialize())
        for _ in 0...31 - priceInWei.count {
            //pad with zeros
            priceInWei.insert(0, at: 0)
        }
        for i in 0...31 {
            buffer.append(priceInWei[i])
        }

        for _ in 0...31 - expiry.count {
            expiry.insert(0, at: 0)
        }

        for i in 0...31 {
            buffer.append(expiry[i])
        }
        //no leading zeros issue here
        var contractAddr = contractAddress.hexa2Bytes

        for i in 0...19 {
            buffer.append(contractAddr[i])
        }

        var tokensUint8 = OrderHandler.uInt16ArrayToUInt8(arrayOfUInt16: tokens)
        for i in 0...tokensUint8.count - 1 {
            buffer.append(tokensUint8[i])
        }

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
