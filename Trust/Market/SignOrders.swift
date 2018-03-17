import BigInt
import TrustKeystore

public struct Order {
    var price: BigUInt
    var indices: [UInt16]
    var expiry: BigUInt
    var contractAddress: String
    //for mapping to server
    var start: BigUInt
    var count: Int
}

public struct SignedOrder {
    var order: Order
    var message: [UInt8]
    var signature: String
}

extension String {
    var hexa2Bytes: [UInt8] {
        let hexa = Array(characters)
        return stride(from: 0, to: count, by: 2).flatMap {
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

public class SignOrders {

    private let keyStore = try! EtherKeystore()

    func signOrders(orders: [Order], account: Account) -> ([SignedOrder], [String]) {
        var signedOrders = [SignedOrder]()
        let data = [String]()

        for i in 0...orders.count - 1 {
            let message: [UInt8] = encodeMessageForTrade(
                    price: orders[i].price,
                    expiryBuffer: orders[i].expiry,
                    tickets: orders[i].indices,
                    contractAddress: orders[i].contractAddress
            )
            let signature = try! "0x" + keyStore.signMessageData(Data(bytes: message), for: account).dematerialize().toHexString()
            let signedOrder = SignedOrder(order: orders[i],
                                          message: message,
                                          signature: signature.description)
            signedOrders.append(signedOrder)
            //encode transaction data
            let v = signature.substring(from: 130)
            let r = signature.substring(to: 64)
            let s = "0x" + signature.substring(with: Range(uncheckedBounds: (64, 126)))
            var hexExpires = orders[i].expiry.serialize().toHexString()
            if (hexExpires == "") {
                hexExpires = "0"
            }
        }
        return (signedOrders, data)
    }

    func encodeMessageForTrade(price: BigUInt,
                               expiryBuffer: BigUInt,
                               tickets: [UInt16],
                               contractAddress: String) -> [UInt8] {
        //ticket count * 2 because it is 16 bits not 8
        let arrayLength: Int = 84 + tickets.count * 2
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

        var ticketsUint8 = SignOrders.uInt16ArrayToUInt8(arrayOfUInt16: tickets)

        for i in 0...ticketsUint8.count - 1 {
            buffer.append(ticketsUint8[i])
        }

        return buffer
    }

    public static func uInt16ArrayToUInt8(arrayOfUInt16: [UInt16]) -> [UInt8] {
        var arrayOfUint8 = [UInt8]()
        for i in 0...arrayOfUInt16.count - 1 {
            var UInt8ArrayPair = arrayOfUInt16[i].bigEndian.data.array
            arrayOfUint8.append(UInt8ArrayPair[0])
            arrayOfUint8.append(UInt8ArrayPair[1])
        }
        return arrayOfUint8
    }

    func bufferToString(buffer: [UInt8]) -> String {
        var bufferString: String = ""
        for i in 0...buffer.count - 1 {
            bufferString += String(buffer[i])
        }
        return bufferString
    }
}
