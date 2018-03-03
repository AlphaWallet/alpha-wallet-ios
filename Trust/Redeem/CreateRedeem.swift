//
// Created by James Sangalli on 2/3/18.
//

import Foundation
import BigInt
import TrustKeystore

class CreateRedeem {

    private let keyStore = try! EtherKeystore()

    func generateRedeem(ticketIndices: [UInt16], account: Account) -> [Data] {
        //TODO remove after testing
        let accountTest = keyStore.createAccount(password: "test")

        var messageAndSignature = [Data]()
        var message = [UInt8]()
        var timestamp = generateTimeStamp()
        let ticketCount = ticketIndices.count * 2
        message.reserveCapacity(ticketCount + timestamp.count)
        message = SignOrders.uInt16ArrayToUInt8(arrayOfUInt16: ticketIndices)
        for i in 0...timestamp.count - 1 {
            message.append(timestamp[i])
        }
        let signature = keyStore.signMessageData(Data(bytes: message), for: accountTest)
        messageAndSignature.append(Data(bytes: message))
        try! messageAndSignature.append(signature.dematerialize())

        print(try! "signature: " + signature.dematerialize().hexString)

        return messageAndSignature
    }

    //optimised for decimal
    func parseToQR(_ data: Data) -> BigInt {
        return BigInt.init(data.hexString, radix: 16)!
    }
    
    func generateTimeStamp() -> [UInt8] {
        let time = Date().timeIntervalSince1970.binade
        let minsTime = (time / 30).binade
        let minsTimeBigUInt = BigUInt(minsTime)
        return Array(minsTimeBigUInt.serialize())
    }
    
}
