////
//// Created by James Sangalli on 15/2/18.
////
//
//import Foundation
//import Just
//
//class OrdersRequest
//{
//    public let baseURL = "https://482kdh4npg.execute-api.ap-southeast-1.amazonaws.com/dev/"
//    public let contractAddress = "0x007bee82bdd9e866b2bd114780a47f2261c684e3" //this is wrong as it is the deployer address, will be corrected later
//
//    public func getOrders()
//    {
//        Just.get(baseURL + "contract/", data: ["contract" : contractAddress]) {
//            r in
//            if r.ok
//            {
//                //handle orders via queue?
//            }
//        }
//    }
//
//    public func giveOrderToServer(signedOrders : [SignedOrder])
//    {
//        Just.put(baseURL + "public-key/" , data : [""]) {
//            r in
//            if r.ok
//            {
//                //success of placing orders
//            }
//        }
//    }
//
//
//}
//
