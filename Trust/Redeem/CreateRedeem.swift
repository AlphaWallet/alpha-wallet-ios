//
// Created by James Sangalli on 2/3/18.
//

import Foundation
import BigInt
import TrustKeystore

class CreateRedeem {

    private let keyStore = try! EtherKeystore()

    func generateTimeStamp() -> String {
        let time = NSDate().timeIntervalSince1970
        let minsTime = Int(time / 30)
        return String(minsTime)
    }

    //TODO make sure the encoding into data is correct for this redeem message
    func redeemMessage(ticketIndices: [UInt16]) -> String {
        var indicesString = ""
        for i in 0...ticketIndices.count - 1 {
            indicesString += String(ticketIndices[i]) + ","
        }
        return indicesString + generateTimeStamp()
    }
    
}
