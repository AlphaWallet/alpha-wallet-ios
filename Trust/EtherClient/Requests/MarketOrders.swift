// Copyright SIX DAY LLC. All rights reserved.

import Foundation

//struct {
//    byte32 contract-address-pad-with-leading-zeros;
//    byte32 price-in-wei;
//    byte32 expiry-in-unix-time;
//    int[3] lot; # lot 2, lot 3, lot 4;
//    byte65 signature1;
//}

public class Order
{
    var price : BigInt;
    var ticketIndices : (short[]);
    var expiryTimeStamp : BigInt;
    var recipient : String;
    var contractAddress : String;
    var v : Int;
    var hexR : String;
    var hexS : String;
}

class MarketOrders
{
    let batch : Batch

    var baseURL : URL {
        return URL(string: "https://i6pk618b7f.execute-api.ap-southeast-1.amazonaws.com/test/abc")!
    }
    
    var method: HTTPMethod {
        return .post
    }
    
    var parameters: Any? {
        return batch.requestObject
    }
    
    typealias response = Array<Order>;
    
    func response(from resultObject: Any) throws -> Response {
        return try batch.responses(from: object)
    }
    
}
