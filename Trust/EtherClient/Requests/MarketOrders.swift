// Copyright SIX DAY LLC. All rights reserved.

import Foundation

//struct {
//    byte32 contract-address-pad-with-leading-zeros;
//    byte32 price-in-wei;
//    byte32 expiry-in-unix-time;
//    int[3] lot; # lot 2, lot 3, lot 4;
//    byte65 signature1;
//}

class Order
{
    var price : BigInt;
    var ticketIndices : short[];
    var expiryTimeStamp : BigInt;
    var recipient : String;
    var contractAddress : String;
    var hexSignature : String;
}

struct MarketOrders : JSONRPCKit.Request {
    
    typealias response = List<Order>;
    
    func response(from resultObject: Any) throws -> Response {
        //if let response = resultObject as? String, let value =
    }
    
}
