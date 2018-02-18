import BigInt
import TrustKeystore
import Trust

//"orders": [
//    {
//    "message": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACOG8m/BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAWojJJwB77oK92ehmsr0RR4CkfyJhxoTjAAIAAwAE)",
//    "expiry": "1518913831",
//    "start": "32800312",
//    "count": "3",
//    "price": "10000000000000000",
//    "signature": "jrzcgpsnV7IPGE3nZQeHQk5vyZdy5c8rHk0R/iG7wpiK9NT730I//DN5Dg5fHs+s4ZFgOGQnk7cXLQROBs9NvgE="
//    }
//]

public struct Order {
    var price: [UInt8]
    var ticketIndices: [UInt16]
    var expiryBuffer: [UInt8]
    var contractAddress: String
}

public struct SignedOrder {
    var order : Order
    var message : Data
    var signature : String
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
    var array: [UInt8] { return Array(self) }
}

public class SignOrders {

    private let keyStore = try! EtherKeystore()

    //takes a list of orders and returns a list of signature objects
    func signOrders(orders : [Order], account : Account) -> [SignedOrder] {

        var signedOrders = [SignedOrder]()

        for i in 0...orders.count - 1 {
            let message : [UInt8] = encodeMessageForTrade(price: orders[i].price,
                    expiryBuffer: orders[i].expiryBuffer, tickets: orders[i].ticketIndices,
                    contractAddress : orders[i].contractAddress)
            let messageData = Data(bytes: message)

            let signature = try! keyStore.signMessageData(messageData, for: account)
            let signedOrder : SignedOrder = try! SignedOrder(order : orders[i], message: messageData,
                    signature : signature.description)
            signedOrders.append(signedOrder)
        }
        return signedOrders
    }

    func encodeMessageForTrade(price: [UInt8], expiryBuffer: [UInt8],
                               tickets: [UInt16], contractAddress: String) -> [UInt8] {
        //ticket count * 2 because it is 16 bits not 8
        let arrayLength: Int = 84 + tickets.count * 2
        var buffer = [UInt8]()
        buffer.reserveCapacity(arrayLength)

        var priceInWei : [UInt8] = price
        var expiry : [UInt8] = expiryBuffer

        for _ in 0...31 - price.count {
            //pad with zeros
            priceInWei.insert(0, at: 0)
        }
        for i in 0...31 {
            buffer.append(priceInWei[i])
        }

        for _ in 0...31 - expiryBuffer.count {
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

        var ticketsUint8 = uInt16ArrayToUInt8(arrayOfUInt16: tickets)

        for i in 0...ticketsUint8.count - 1 {
            buffer.append(ticketsUint8[i])
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

}
