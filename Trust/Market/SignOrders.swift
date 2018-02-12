import BigInt
import TrustKeystore
import Trust

public struct Order {
    var price: BigInt
    var ticketIndices: [UInt16]
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
        for i in 0...orders.count {
            //sign each order
            //TODO check casting to string
            let message = encodeMessageForTrade(price: orders[i].price,
                    expiryTimestamp: orders[i].expiryTimeStamp, tickets: orders[i].ticketIndices)
            let signature = keyStore.signMessage(message, for: account)
            let signedOrder : SignedOrder = try! SignedOrder(order : orders[i], message: message, signature : signature.dematerialize().hexString)
            signedOrders.append(signedOrder)
        }
        return signedOrders
    }

    func encodeMessageForTrade(price : BigInt, expiryTimestamp : BigInt, tickets : [UInt16]) -> String {
        //TODO array of BigInt instead?
        let arrayLength: Int = 84 + tickets.count * 2
        var buffer = [UInt16]()
        buffer.reserveCapacity(arrayLength)
        //TODO fix lea"[UInt16]" issue either here or in method that calls this
        var priceInWeiBuffer = [UInt16] (price.description.utf16)
        for i in 0...31 {
            buffer.append(priceInWeiBuffer[i])
        }
        var expiryBuffer = [UInt16] (expiryTimestamp.description.utf16)
        for i in 0...31 {
            buffer.append(expiryBuffer[i])
        }
        //no leading zeros issue here
        var contractAddress = [UInt16] (CONTRACT_ADDR.utf16)
        for i in 0...19 {
            buffer.append(contractAddress[i])
        }
        for i in 0...tickets.count {
            buffer.append(tickets[i])
        }
        return buffer.description
    }

}
