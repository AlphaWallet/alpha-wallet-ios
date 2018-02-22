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

    //TODO batch orders
    public func giveOrderToServer(signedOrders : [SignedOrder], publicKeyHex : String,
                                  callback: @escaping (_ result: Any) -> Void)
    {
        for i in 0...signedOrders.count - 1 {

            var query : String = baseURL + "/publickey/" + publicKeyHex
            query += "?start=" + signedOrders[i].order.start.description
            query += ";count=" + signedOrders[i].order.count.description

            let parameters : Parameters = [
                "data": signedOrders[i].signature
            ]

            let headers: HTTPHeaders = [
                "Content-Type": "application/vnd.awallet-signed-orders-v0"
            ]

            Alamofire.request(query,
                    method: .put,
                    parameters: parameters,
                    encoding: JSONEncoding.default,
                    headers: headers).responseJSON {
                response in
                callback(response)
            }
        }
    }

}
