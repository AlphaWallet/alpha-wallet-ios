//
// Created by James Sangalli on 2/3/18.
//

import Foundation
import BigInt
import TrustKeystore

class CreateRedeem {

    private let keyStore = try! EtherKeystore()

    func generateRedeem(ticketIndices: [UInt16]) -> Data {
        var message = [UInt8]()
        var timestamp = generateTimeStamp()
        let ticketCount = ticketIndices.count * 2
        message.reserveCapacity(ticketCount + timestamp.count)
        message = SignOrders.uInt16ArrayToUInt8(arrayOfUInt16: ticketIndices)
        for i in 0...timestamp.count - 1 {
            message.append(timestamp[i])
        }
        return Data(bytes: message)
    }
    
    func generateTimeStamp() -> [UInt8] {
        let time = Date().timeIntervalSince1970.binade
        let minsTime = (time / 30).binade
        let minsTimeBigUInt = BigUInt(minsTime)
        return Array(minsTimeBigUInt.serialize())
    }
    
}
