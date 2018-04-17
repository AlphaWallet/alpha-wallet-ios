//
// Created by James Sangalli on 24/3/18.
//

/**
 * Universal link format
 *
 * Android requires the link to be in the form:
 *
 * https://www.awallet.io/[base64]
 *
 * The format forbids using a prefix other than 'www'.
 * There needs to be text in the specific link too, in this case 'import'.
$ echo -n https://www.awallet.io/; \
  echo -n 000f42405AB5B400007bee82bdd9e866b2bd114780a47f2261c684e30102030405060708092F982B84C635967A9B6306ED5789A7C1919164171E37DCCDF4B59BE54754410530818B896B7D240F56C59EBDF209062EE54DA7A3590905739674DCFDCECF3E9B1b | xxd -r -p | base64;\
https://app.awallet.io/AA9CQFq1tAAAe+6CvdnoZrK9EUeApH8iYcaE4wECAwQFBgcICS+YK4TGNZZ6m2MG7VeJp8GRkWQXHjfczfS1m+VHVEEFMIGLiWt9JA9WxZ698gkGLuVNp6NZCQVzlnTc/c7PPpsb
 * uint32:    price in Szabo                                           000f4240
 * uint32:    expiry in Unix Time                                      5AB5B400
 * bytes20:   contract address         007bee82bdd9e866b2bd114780a47f2261c684e3
 * Uint16[]:  ticket indices                               010203040506070809
 * bytes32:    2F982B84C635967A9B6306ED5789A7C1919164171E37DCCDF4B59BE547544105
 * bytes32:    30818B896B7D240F56C59EBDF209062EE54DA7A3590905739674DCFDCECF3E9B
 * byte:                                                                     1b
 * 1521857536, [0,1,2,3,4,5,6,7,8,9], 27, "0x2F982B84C635967A9B6306ED5789A7C1919164171E37DCCDF4B59BE547544105", "0x30818B896B7D240F56C59EBDF209062EE54DA7A3590905739674DCFDCECF3E9B" -> 0xd2bef24c7e90192426b54bf437a5eac4e220dde7
 */

import Foundation
import BigInt

public class UniversalLinkHandler {

    public let urlPrefix = "https://app.awallet.io/"
    public static let paymentServer = "http://feemaster.eastasia.cloudapp.azure.com:8080/api/claimToken"

    //message is with 32 bytes each of price and expiry and is shortened for link
    func createUniversalLink(signedOrder: SignedOrder) -> String {
        let message = formatMessageForLink(signedOrder: signedOrder)
        let signature = signedOrder.signature
        let link = (message + signature).hexa2Bytes
        let binaryData = Data(bytes: link)
        let base64String = binaryData.base64EncodedString()

        return urlPrefix + base64String
    }
    
    //TODO add exception handling
    //link has shortened price and expiry and must be expanded
    func parseUniversalLink(url: String) -> SignedOrder {
        let linkInfo = url.substring(from: urlPrefix.count)
        let linkBytes = Data(base64Encoded: linkInfo)?.array
        let price = getPriceFromLinkBytes(linkBytes: linkBytes!)
        let expiry = getExpiryFromLinkBytes(linkBytes: linkBytes!)
        let contractAddress = getContractAddressFromLinkBytes(linkBytes: linkBytes!)
        let ticketIndices = getTicketIndicesFromLinkBytes(linkBytes: linkBytes!)
        let (v, r, s) = getVRSFromLinkBytes(linkBytes: linkBytes!)
        let order = Order(
            price: price,
            indices: ticketIndices,
            expiry: expiry,
            contractAddress: contractAddress,
            start: BigUInt("0")!,
            count: ticketIndices.count
        )
        let message = getMessageFromOrder(order: order)
        return SignedOrder(order: order, message: message, signature: "0x" + r + s + v)
    }
    
    //we used a special encoding so that one 16 bit number could represent either one ticket or two
    //this is for the purpose of keeping universal links as short as possible
    func decodeTicketIndices(indices: [UInt16]) -> [UInt8] {
        var indicesBytes = [UInt8]()
        for i in 0...indices.count - 1 {
            let index = indices[i]
            if(index < 128) {
                let byte = UInt8(index)
                indicesBytes.append(byte)
            } else {
                //Top 7 bits
                let firstByteHigh = UInt8(128 + (index >> 8))
                //bottom 8 bits
                let secondByteLow = UInt8(index & 255)
                indicesBytes.append(firstByteHigh)
                indicesBytes.append(secondByteLow)
            }
        }
        return indicesBytes
    }
    
    //shortens price and expiry
    func formatMessageForLink(signedOrder: SignedOrder) -> String {
        let message = signedOrder.message
        let indices = decodeTicketIndices(indices: signedOrder.order.indices)
        var messageWithSzabo = [UInt8]()
        let price = Array(message[0...31])
        let expiry = Array(message[32...63])
        let priceHex = MarketQueueHandler.bytesToHexa(price)
        let expiryHex = MarketQueueHandler.bytesToHexa(expiry)
        //removes leading zeros
        let priceInt = BigUInt(priceHex, radix: 16)!
        let expiryInt = BigUInt(expiryHex, radix: 16)!
        //change from wei to szabo
        let priceSzabo = priceInt / 1000000000000
        var priceBytes = formatTo4Bytes(priceSzabo.serialize().bytes)
        var expiryBytes = formatTo4Bytes(expiryInt.serialize().bytes)
        for i in 0...3 {
            messageWithSzabo.append(priceBytes[i])
        }
        for i in 0...3 {
            messageWithSzabo.append(expiryBytes[i])
        }
        for i in 64...83 {
            messageWithSzabo.append(message[i])
        }
        for i in 0...indices.count - 1 {
            messageWithSzabo.append(indices[i])
        }
        return MarketQueueHandler.bytesToHexa(messageWithSzabo)
    }
    
    func formatTo4Bytes(_ array: [UInt8]) -> [UInt8] {
        var formattedArray = [UInt8]()
        if array.count == 4 {
            return array
        } else if array.isEmpty {
            for _ in 0...3 {
                formattedArray.append(0)
            }
            return formattedArray
        } else {
            let missingDigits = 4 - array.count
            for _ in 0...missingDigits - 1 {
                formattedArray.append(0)
            }
            return formattedArray
        }
    }

    func getPriceFromLinkBytes(linkBytes: [UInt8]) -> BigUInt {
        var priceBytes = [UInt8]()
        for i in 0...3 {
            //price in szabo
            priceBytes.append(linkBytes[i])
        }
        let priceHex = MarketQueueHandler.bytesToHexa(priceBytes)
        let price = BigUInt(priceHex, radix: 16)!
        return price * 1000000000000
    }

    func getExpiryFromLinkBytes(linkBytes: [UInt8]) -> BigUInt {
        var expiryBytes = [UInt8]()
        for i in 4...7 {
            expiryBytes.append(linkBytes[i])
        }
        let expiry = MarketQueueHandler.bytesToHexa(expiryBytes)
        return BigUInt(expiry, radix: 16)!
    }

    func getContractAddressFromLinkBytes(linkBytes: [UInt8]) -> String {
        var contractAddrBytes = [UInt8]()
        for i in 8...27 {
            contractAddrBytes.append(linkBytes[i])
        }
        return MarketQueueHandler.bytesToHexa(contractAddrBytes)
    }

    func getTicketIndicesFromLinkBytes(linkBytes: [UInt8]) -> [UInt16] {

        let ticketLength = linkBytes.count - (65 + 20 + 8) - 1
        var ticketIndices = [UInt16]()
        var state: Int = 1
        var currentIndex: UInt16 = 0
        let ticketStart = 28

        for i in stride(from: ticketStart, through: ticketStart + ticketLength, by: 1) {
            let byte: UInt8 = linkBytes[i]
            switch(state) {
                case 1:
                    //8th bit is equal to 128, if not set then it is only one ticket and will change the state
                    if(byte & (128) == 128) { //should be done with masks
                        currentIndex = UInt16((byte & 127)) << 8
                        state = 2
                    }
                    else {
                        ticketIndices.append(UInt16(byte))
                    }
                    break
                case 2:
                    currentIndex += UInt16(byte)
                    ticketIndices.append(currentIndex)
                    state = 1
                    break
                default:
                    break
            }
        }
        return ticketIndices
    }
    
    func getVRSFromLinkBytes(linkBytes: [UInt8]) -> (String, String, String) {
        var signatureStart = linkBytes.count - 65
        var rBytes = [UInt8]()
        for i in signatureStart...signatureStart + 31 {
            rBytes.append(linkBytes[i])
        }
        let r = MarketQueueHandler.bytesToHexa(rBytes)
        signatureStart += 32
        var sBytes = [UInt8]()
        for i in signatureStart...signatureStart + 31 {
            sBytes.append(linkBytes[i])
        }
        let s = MarketQueueHandler.bytesToHexa(sBytes)
        let v = String(format:"%2X", linkBytes[linkBytes.count - 1]).trimmed
        return (v, r, s)
    }
    
    //price and expiry need to be 32 bytes each
    func getMessageFromOrder(order: Order) -> [UInt8] {
        var message = [UInt8]()
        //encode price and expiry first
        let priceBytes = padTo32(order.price.serialize().array)
        for i in 0...31 {
            message.append(priceBytes[i])
        }
        let expiryBytes = padTo32(order.expiry.serialize().array)
        for i in 0...31 {
            message.append(expiryBytes[i])
        }
        let contractBytes = order.contractAddress.hexa2Bytes
        for i in 0...19 {
            message.append(contractBytes[i])
        }
        let indices = OrderHandler.uInt16ArrayToUInt8(arrayOfUInt16: order.indices)
        for i in 0...indices.count - 1 {
            message.append(indices[i])
        }
        return message
    }
    
    func padTo32(_ buffer: [UInt8], to count: Int = 32) -> [UInt8] {
        let padCount = count - buffer.count
        var padded = buffer
        let padding: [UInt8] = Array(repeating: 0, count: padCount)
        padded.insert(contentsOf: padding, at: 0)
        return padded
    }

}
