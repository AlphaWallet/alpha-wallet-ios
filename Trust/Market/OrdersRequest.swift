//
// Created by James Sangalli on 15/2/18.
//

import Foundation
import Just

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
    
    public func getOrders(callback: @escaping (_ result : Any) -> ()) {
        Just.get(baseURL + "contract/" + contractAddress) {
            r in
            if r.ok
            {
                callback(r)
            }
            else
            {
                callback(r.error)
            }
        }
    }
    
    public func giveOrderToServer(signedOrders : [SignedOrder], publicKeyHex : String,
                                  callback: @escaping (_ result: Any) -> ()) {
        Just.put(baseURL + "public-key/" , data : ["" : publicKeyHex]) {
            r in
            if r.ok
            {
                //success of placing orders
                callback(r)
            }
            else
            {
                callback(r.error)
            }
        }
    }
    
}



