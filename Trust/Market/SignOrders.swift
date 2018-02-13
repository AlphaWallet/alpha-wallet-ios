import BigInt
import TrustKeystore
import Trust

public struct Order {
    var price: BigInt
    var ticketIndices: [UInt8]
    var expiryTimeStamp: BigInt
    var contractAddress: String
}

public struct SignedOrder {
    var order : Order
    var message : String
    var signature : String
}

public class SignOrders {

    public let CONTRACT_ADDR = "0xd9864b424447B758CdE90f8655Ff7cA4673956bf"
    private let keyStore = try! EtherKeystore()


    //takes a list of orders and returns a list of signature objects
    func signOrders(orders : Array<Order>, account : Account) -> Array<SignedOrder> {
        var signedOrders : Array<SignedOrder> = Array<SignedOrder>()
        //EtherKeystore.signMessage(encodeMessage(), )
        for i in 0...orders.count - 1 {
            //sign each order
            //TODO check casting to string
            let message : String = encodeMessageForTrade(price: orders[i].price,
                    expiryTimestamp: orders[i].expiryTimeStamp, tickets: orders[i].ticketIndices,
                    contractAddress : orders[i].contractAddress)
            let signature = try! keyStore.signMessage(message, for: account)
            let signedOrder : SignedOrder = try! SignedOrder(order : orders[i], message: message,
                    signature : signature.description)
            signedOrders.append(signedOrder)
        }
        return signedOrders
    }

    //TODO fix this encoding as it doesn't match solidity ecrecover
    //price is casted wrong
    func encodeMessageForTrade(price : BigInt, expiryTimestamp : BigInt,
                               tickets : [UInt8], contractAddress : String) -> String {

        let arrayLength: Int = 102 + tickets.count * 2 //84 + tickets.count * 2
        var buffer = [UInt8]()
        buffer.reserveCapacity(arrayLength)
        //TODO represent as Uint16 and cast back into uint8
        var priceInWei = [UInt8] (price.description.utf8)
        for i in 0...31 - priceInWei.count {
            //pad with zeros
            priceInWei.insert(0, at: 0)
        }
        for i in 0...31 {
            buffer.append(priceInWei[i])
        }

        var expiryBuffer = [UInt8] (expiryTimestamp.description.utf8)

        for i in 0...31 - expiryBuffer.count {
            expiryBuffer.insert(0, at: 0)
        }

        for i in 0...31 {
            buffer.append(expiryBuffer[i])
        }
        //no leading zeros issue here
        var contractAddress = [UInt8] (contractAddress.utf8)

        for i in 0...39 {
            buffer.append(contractAddress[i])
        }

        for i in 0...tickets.count - 1 {
            buffer.append(tickets[i])
        }

        return buffer.description
    }

}
