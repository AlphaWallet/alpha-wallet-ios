//
// Created by James Sangalli on 15/2/18.
//
import Foundation
import Alamofire
import SwiftyJSON
import BigInt

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

public class OrdersRequest {

    public let baseURL = "https://482kdh4npg.execute-api.ap-southeast-1.amazonaws.com/dev/"
    public let contractAddress = "0xbc9a1026a4bc6f0ba8bbe486d1d09da5732b39e4"
    private let methodSig = "0xa6fb475f"

    public func getOrders(callback: @escaping (_ result : Any) -> Void) {
        Alamofire.request(baseURL + "contract/" + contractAddress, method: .get).responseJSON {
            response in
            var orders = [SignedOrder]()
            if let json = response.result.value {
                let parsedJSON = try! JSON(data: response.data!)
                for i in 0...parsedJSON.count - 1 {
                    let orderObj: JSON = parsedJSON["orders"][i]
                    orders.append(self.parseOrder(orderObj))
                }
                callback(self.encodeOrderToTrade(orders: orders))
            }
        }
    }
    //TODO change this to model the Coordinators in TokensDataStore
    //trade data encoding example: https://rinkeby.etherscan.io/tx/0x5037827ac882c037c5632cb78497df1f213e0d8c068cd0fd3621c1d25eadb63c
    func encodeOrderToTrade(orders: [SignedOrder]) -> [String] {
        var listOfEncodedData = [String]()
        for i in 0...orders.count - 1 {
            var encoding = methodSig + padWith32ByteLengthZeros(orders[i].order.expiry.serialize().hexEncoded)
            encoding += padWith32ByteLengthZeros(
                    //indices
                    bytesToHexa(SignOrders.uInt16ArrayToUInt8(arrayOfUInt16: orders[i].order.indices))
            )
            let signature = orders[i].signature
            let v = padWith32ByteLengthZeros(signature.substring(from: 130))
            let r = signature.substring(to: 66)
            let s = signature.substring(with: Range(uncheckedBounds: (66, 128)))
            encoding += v + r + s
            listOfEncodedData.append(encoding)
        }
        return listOfEncodedData
    }

    func padWith32ByteLengthZeros(_ item: String) -> String {
        var newItem: String = ""
        for _ in 0...64 - item.count {
            newItem += "0"
        }
        newItem += item
        return newItem
    }

    func parseOrder(_ orderObj: JSON) -> SignedOrder {
        let orderString = orderObj["message"].string!
        let message = bytesToHexa(Array(Data(base64Encoded: orderString.substring(to: orderString.count - 1))!))
        let price = message.substring(to: 64)
        let expiry = message.substring(with: Range(uncheckedBounds: (64, 128)))
        let contractAddress = "0x" + message.substring(with: Range(uncheckedBounds: (128, 168)))
        let indices = message.substring(from: 168)
        let order = Order(
                price: BigUInt(price, radix: 16)!,
                indices: indices.hexa2Bytes.map({ UInt16($0) }),
                expiry: BigUInt(expiry, radix: 16)!,
                contractAddress: contractAddress,
                start: BigUInt(orderObj["start"].string!)!,
                count: orderObj["count"].intValue
        )
        let signedOrder = SignedOrder(
                order: order,
                message: message.hexa2Bytes,
                signature: "0x" + bytesToHexa(Array(Data(base64Encoded: orderObj["signature"].string!)!))
        )
        return signedOrder
    }

    //only have to give first order to server then pad the signatures
    func putOrderToServer(signedOrders : [SignedOrder], publicKey: String,
                             callback: @escaping (_ result: Any) -> Void) {
        //TODO get encoding for count and start
        let query : String = baseURL + "public-key/" + publicKey + "?start=" +
                signedOrders[0].order.start.description + ";count=" + signedOrders[0].order.count.description
        var data = signedOrders[0].message

        for i in 0...signedOrders.count - 1 {
            for j in 0...64 {
                data.append(signedOrders[i].signature.hexa2Bytes[j])
            }
        }

        let hexData : String = bytesToHexa(data)
        let parameters : Parameters = [
            "data": hexData
        ]
        let headers: HTTPHeaders = [
            "Content-Type": "application/vnd.awallet-signed-orders-v0"
        ]

        Alamofire.request(query, method: .put, parameters: parameters,
                encoding: JSONEncoding.default, headers: headers).responseJSON {
            response in

            if let json = response.result.value {
                let parsedJSON = try! JSON(parseJSON: (json as! String))
                callback(parsedJSON["orders"]["accepted"])
            }

            if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
                print("Data: \(utf8Text)") // original server data as UTF8 string
            }
        }
    }

    func bytesToHexa(_ bytes: [UInt8]) -> String {
        return bytes.map{ String(format: "%02X", $0) }.joined()
    }

}
