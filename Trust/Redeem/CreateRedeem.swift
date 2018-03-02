//
// Created by James Sangalli on 2/3/18.
//

import Foundation
import TrustKeystore

class CreateRedeem {

    private let keyStore = try! EtherKeystore()

    func generateRedeem(ticketIndices: [UInt16], account: Account) -> [Data] {
        var messageAndSignature = [Data]()
        let message = SignOrders.uInt16ArrayToUInt8(arrayOfUInt16: ticketIndices)
        let signature = keyStore.signMessage(Data(bytes: message), for: account)
        messageAndSignature.append(Data(bytes: message))
        try! messageAndSignature.append(signature.dematerialize())

        return messageAndSignature
    }

}