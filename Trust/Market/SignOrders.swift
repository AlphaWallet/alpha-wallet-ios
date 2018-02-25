import BigInt
import TrustKeystore
import Trust

public struct Order {
    var price: BigInt
    var start: UInt16
    var count: Int
    var expiryBuffer: BigInt
    var contractAddress: String
}

public struct SignedOrder {
    var order: Order
    var message: [UInt8]
    var signature: String
}

extension BinaryInteger {
    var data: Data {
        var source = self
        return Data(bytes: &source, count: MemoryLayout<Self>.size)
    }
}

extension String {
    var hexa2Bytes: [UInt8] {
        let hexa = Array(characters)
        return stride(from: 0, to: count, by: 2).flatMap { UInt8(String(hexa[$0..<$0.advanced(by: 2)]), radix: 16) }
    }
}

extension Data {
    var array: [UInt8] { return Array(self) }
}

public class SignOrders {

    private let keyStore = try! EtherKeystore()

    //takes a list of orders and returns a list of signature objects
    func signOrders(orders : Array<Order>, account : Account) -> Array<SignedOrder> {

        var signedOrders : Array<SignedOrder> = Array<SignedOrder>()

        for i in 0...orders.count - 1 {
            let message : [UInt8] =
            encodeMessageForTrade(
                    price: orders[i].price,
                    expiryBuffer: orders[i].expiryBuffer,
                    start: orders[i].start,
                    count: orders[i].count,
                    contractAddress : orders[i].contractAddress
            )

            let signature = try! keyStore.signMessageData(Data(bytes: message), for: account)
            let signedOrder : SignedOrder = try! SignedOrder(order : orders[i], message: message,
                    signature : signature.description)
            signedOrders.append(signedOrder)
        }
        return signedOrders
    }

    func encodeMessageForTrade(price: BigInt, expiryBuffer: BigInt, start: UInt16,
                               count: Int, contractAddress: String) -> [UInt8] {
        //ticket count * 2 because it is 16 bits not 8
        let arrayLength: Int = 84 + count * 2
        var buffer = [UInt8]()
        buffer.reserveCapacity(arrayLength)

        var priceInWei: [UInt8] = toByteArray(price)
        var expiry: [UInt8] = toByteArray(expiryBuffer)

        for _ in 0...31 - price.bitWidth / 8 {
            //pad with zeros
            priceInWei.insert(0, at: 0)
        }
        for i in 0...31 {
            buffer.append(priceInWei[i])
        }

        for _ in 0...31 - expiryBuffer.bitWidth / 8 {
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

        var indices : [UInt16] = [UInt16]()

        for i in 0...count {
            let ticket : UInt16 = start + UInt16(i);
            indices.append(ticket)
        }

        var uint8Indices = uInt16ArrayToUInt8(arrayOfUInt16: indices)

        for i in 0...count {
            buffer.append(uint8Indices[i])
        }

        return buffer
    }

    func uInt16ArrayToUInt8(arrayOfUInt16: [UInt16]) -> [UInt8] {
        var arrayOfUint8 = [UInt8]()
        for i in 0...arrayOfUInt16.count - 1 {
            var UInt8ArrayPair = arrayOfUInt16[i].bigEndian.data.array
            arrayOfUint8.append(UInt8ArrayPair[0])
            arrayOfUint8.append(UInt8ArrayPair[1])
        }
        return arrayOfUint8
    }

    func toByteArray<T>(_ value: T) -> [UInt8] {
        var value = value
        return withUnsafePointer(to: &value) {
            $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<T>.size) {
                Array(UnsafeBufferPointer(start: $0, count: MemoryLayout<T>.size))
            }
        }
    }

}
