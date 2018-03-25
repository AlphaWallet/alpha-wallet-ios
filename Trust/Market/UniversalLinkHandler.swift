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

https://www.awallet.io/AA9CQFq1tAAAe+6CvdnoZrK9EUeApH8iYcaE4wECAwQFBgcICQovmCuExjWWeptjBu1XiafBkZFkFx433M30tZvlR1RBBTCBi4lrfSQPVsWevfIJBi7lTaejWQkFc5Z03P3Ozz6bb
 * uint32:    price in Szabo                                           000f4240
 * uint32:    expiry in Unix Time                                      5AB5B400
 * bytes20:   contract address         007bee82bdd9e866b2bd114780a47f2261c684e3
 * Uint16[]:  ticket indices                               0102030405060708090a
 * bytes32:    2F982B84C635967A9B6306ED5789A7C1919164171E37DCCDF4B59BE547544105
 * bytes32:    30818B896B7D240F56C59EBDF209062EE54DA7A3590905739674DCFDCECF3E9B
 * byte:                                                                     1b
 *
 */

import Foundation
import BigInt

public class UniversalLinkHandler {

    static func parseURL(url: String) -> SignedOrder {
        var ticketIndices = [UInt16]()
        let linkInfo = url.substring(from: 23)
        let linkBytes = Data(base64Encoded: linkInfo)?.array

        var priceBytes = [UInt8]()
        for i in 0...3 {
            //price in szabo
            priceBytes.append(linkBytes![i])
        }
        let price = BigUInt(OrdersRequest.bytesToHexa(priceBytes), radix: 16)?.multiplied(by: BigUInt("1000000000000")!)

        var expiryBytes = [UInt8]()
        for i in 4...7 {
            expiryBytes.append(linkBytes![i])
        }
        let expiry = OrdersRequest.bytesToHexa(expiryBytes)

        var contractAddrBytes = [UInt8]()
        for i in 8...28 {
            contractAddrBytes.append(linkBytes![i])
        }
        let contractAddress = OrdersRequest.bytesToHexa(contractAddrBytes)

        let ticketLength = (linkBytes?.count)! - (65 + 20 + 8)

        for i in stride(from: 28, through: 28 + ticketLength, by: 2) {
            var ticket = [UInt8]()
            for _ in 0...2 {
                ticket.append(linkBytes![i])
            }
            let binaryTicket = String((UInt16(ticket[1]) << 8) + UInt16(ticket[0]), radix: 2)

            if(binaryTicket.substring(to: 1) == "0")
            {
                //just one ticket
                let result = (UInt16(ticket[1]) << 8) + UInt16(ticket[0])
                ticketIndices.append(result)
            }
            else
            {
                ticketIndices.append(UInt16(ticket[1]) << 8)
                ticketIndices.append(UInt16(ticket[0]))
            }
        }

        var signatureStart = (linkBytes?.count)! - 64
        var sBytes = [UInt8]()
        for i in signatureStart...signatureStart + 31
        {
            sBytes.append(linkBytes![i])
        }
        signatureStart += 31
        let s = OrdersRequest.bytesToHexa(sBytes)

        var rBytes = [UInt8]()
        for i in signatureStart...signatureStart + 31 {
            rBytes.append(linkBytes![i])
        }

        let r = OrdersRequest.bytesToHexa(rBytes)
        let v = String(format:"%2X", linkBytes![(linkBytes?.count)! - 1])

        let order = Order(
                price: price!,
                indices: ticketIndices,
                expiry: BigUInt(expiry, radix: 16)!,
                contractAddress: contractAddress,
                start: BigUInt("0")!,
                count: ticketIndices.count
        )

        var message = [UInt8]()
        for i in 0...ticketLength + 84 {
            message.append(linkBytes![i])
        }

        return SignedOrder(order: order, message: message, signature: "0x" + r + s + v)
    }

}