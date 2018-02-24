//
// Created by James Sangalli on 15/2/18.
//

import Foundation
import Alamofire

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
    public let contractAddress = "0x007bee82bdd9e866b2bd114780a47f2261c684e3" //this is wrong as it is the deployer address, will be corrected later

    public func getOrders(callback: @escaping (_ result : Any) -> Void) {
        Alamofire.request(baseURL + "/contract/" + contractAddress, method: .get).responseJSON {
            response in
            callback(response)
        }
    }

    //only have to give first order to server then pad the signatures
    public func giveOrderToServer(signedOrders : [SignedOrder], publicKey: String,
                                  callback: @escaping (_ result: Any) -> Void)
    {
        let query : String = baseURL + "public-key/" + publicKey + "?start=" +
                signedOrders[0].order.start.description + ";count="
        + signedOrders[0].order.count.description
        var data: [UInt8] = signedOrders[0].message.array

        for i in 0...signedOrders.count - 1 {
            for j in 0...64 {
                data.append(signedOrders[i].signature.hexa2Bytes[i])
            }
        }

        let parameters : Parameters = [
            "data": data
        ]

        let headers: HTTPHeaders = [
            "Content-Type": "application/vnd.awallet-signed-orders-v0"
        ]

        Alamofire.request(query, method: .put, parameters: parameters,
                encoding: JSONEncoding.default, headers: headers).responseJSON {
            response in
            print("Request: \(String(describing: response.request))")   // original url request
            print("Response: \(String(describing: response.response))") // http url response
            print("Result: \(response.result)")                         // response serialization result

            if let json = response.result.value {
                print("JSON: \(json)") // serialized json response
                callback(json)
            }

            if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
                print("Data: \(utf8Text)") // original server data as UTF8 string
            }
        }

    }

}
