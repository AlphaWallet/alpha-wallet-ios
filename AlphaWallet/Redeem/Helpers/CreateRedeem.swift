//
// Created by James Sangalli on 2/3/18.
// Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import BigInt

class CreateRedeem {
    private let token: TokenObject

    init(token: TokenObject) {
        self.token = token
    }

    func generateTimeStamp() -> String {
        let time = NSDate().timeIntervalSince1970
        //rotate qr every 30 seconds for security (preventing screenshot claims)
        let minsTime = Int(time / 30) 
        return String(minsTime)
    }

    func redeemMessage(tokenIds: [BigUInt]) -> (message: String, qrCode: String) {
        let contractAddress = token.contractAddress.eip55String.lowercased()
        let messageForSigning = tokensToHexStringArray(tokens: tokenIds)
                + "," + generateTimeStamp() + "," + contractAddress
        let qrCodeData = tokensToHexStringArray(tokens: tokenIds)
        return (messageForSigning, qrCodeData)
    }

    private func tokensToHexStringArray(tokens: [BigUInt]) -> String {
        //padding to 32 bytes can be done on the ushers side
        return tokens.map({ $0.serialize().hexString }).joined(separator: ",")
    }

}
