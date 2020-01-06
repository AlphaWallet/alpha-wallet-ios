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

    private func generateTimeStamp() -> String {
        let time = NSDate().timeIntervalSince1970
        //rotate qr every 30 seconds for security (preventing screenshot claims)
        let minsTime = Int(time / 30)
        return String(minsTime)
    }

    private func generateTimeStamp721Tickets() -> String {
        let time = NSDate().timeIntervalSince1970
        //use ten minute intervals
        let minsTime = Int(time / 600)
        return String(minsTime)
    }

    func redeemMessage(tokenIds: [BigUInt]) -> (message: String, qrCode: String) {
        let contractAddress = token.contractAddress.eip55String.lowercased()
        //TODO this only works with one token at a time
        let tokensAsDecimalString = tokensToDecimalString(tokens: tokenIds)
        var prefix = "0"
        if tokensAsDecimalString.count < 10 {
            prefix += ("0" + tokensAsDecimalString.count.description)
        } else {
            prefix += tokensAsDecimalString.count.description
        }
        let qrCodeData = prefix + tokensAsDecimalString
        let messageForSigning = prefix + tokensToDecimalString(tokens: tokenIds)
            + "," + generateTimeStamp721Tickets() + "," + contractAddress
        return (messageForSigning, qrCodeData)
    }

    func redeemMessage(indices: [UInt16]) -> (message: String, qrCode: String) {
        let contractAddress = token.contractAddress.eip55String.lowercased()
        let messageForSigning = formIndicesSelection(indices: indices)
                + "," + generateTimeStamp() + "," + contractAddress
        let qrCodeData = formIndicesSelection(indices: indices)
        return (messageForSigning, qrCodeData)
    }

    private func tokensToDecimalString(tokens: [BigUInt]) -> String {
        //padding to 32 bytes can be done on the ushers side
        return tokens.map({ $0.description }).joined(separator: ",")
    }

    private func formIndicesSelection(indices: [UInt16]) -> String {
        let firstValue = indices[0] //lowest number
        let NIBBLE = 4
        let zeroCount = Int(firstValue) / NIBBLE
        let correctionFactor = zeroCount * NIBBLE
        /* the method here is easier to express with matrix programming like this:
        indexList = indexList - correctionFactor # reduce every element of the list by an int
        selection = sum(2^indexList)             # raise every element and add the result back */
        var bitFieldLookup = BigUInt(0)
        for _ in 0...indices.count - 1 {
            let adder = BigUInt(2).power(Int(indices[0]) - correctionFactor)
            bitFieldLookup = bitFieldLookup.advanced(by: BigInt(adder))
        }

        let bitIntLength: Int = bitFieldLookup.description.count
        var bitString = ""
        if bitIntLength < 10 {
            bitString = "0"
        }
        bitString += String(bitIntLength)
        if zeroCount < 100 {
            bitString += "0"
        }
        if zeroCount < 10 {
            bitString += "0"
        }

        bitString += String(zeroCount)
        bitString += String(bitFieldLookup)

        return bitString
    }

}
