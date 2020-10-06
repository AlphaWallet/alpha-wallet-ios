//
// Created by James Sangalli on 24/3/18.
// Copyright © 2018 Stormbird PTE. LTD.
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
https://aw.app/AA9CQFq1tAAAe+6CvdnoZrK9EUeApH8iYcaE4wECAwQFBgcICS+YK4TGNZZ6m2MG7VeJp8GRkWQXHjfczfS1m+VHVEEFMIGLiWt9JA9WxZ698gkGLuVNp6NZCQVzlnTc/c7PPpsb
 * uint32:    price in Szabo                                           000f4240
 * uint32:    expiry in Unix Time                                      5AB5B400
 * bytes20:   contract address         007bee82bdd9e866b2bd114780a47f2261c684e3
 * Uint16[]:  token indices                               010203040506070809
 * bytes32:    2F982B84C635967A9B6306ED5789A7C1919164171E37DCCDF4B59BE547544105
 * bytes32:    30818B896B7D240F56C59EBDF209062EE54DA7A3590905739674DCFDCECF3E9B
 * byte:                                                                     1b
 * 1521857536, [0,1,2,3,4,5,6,7,8,9], 27, "0x2F982B84C635967A9B6306ED5789A7C1919164171E37DCCDF4B59BE547544105", "0x30818B896B7D240F56C59EBDF209062EE54DA7A3590905739674DCFDCECF3E9B" -> 0xd2bef24c7e90192426b54bf437a5eac4e220dde7
 */

import Foundation
import BigInt

private enum LinkFormat: UInt8 {
    case unassigned = 0x00
    case normal = 0x01
    case spawnable = 0x02
    case customizable = 0x03
    case nativeCurrencyLink = 0x04
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

public class UniversalLinkHandler {
    private let server: RPCServer

    init(server: RPCServer) {
        self.server = server
    }

    //message is with 32 bytes each of price and expiry and is shortened for link
    func createUniversalLink(signedOrder: SignedOrder, tokenType: TokenType) -> String {
        let prefix = server.magicLinkPrefix.description
        let message: String
        switch tokenType {
        case .erc721ForTickets:
            message = formatMessageForLink721Ticket(signedOrder: signedOrder)
        case .erc875:
            message = formatMessageForLink(signedOrder: signedOrder)
        case .nativeCryptocurrency, .erc20, .erc721:
            // Should never happen
            return ""
        }
        let signature = signedOrder.signature
        let link = (message + signature).hexToBytes
        let binaryData = Data(bytes: link)
        let base64String = binaryData.base64EncodedString()
        return prefix + b64SafeEncoding(base64String)
    }

    private func b64SafeEncoding(_ b64String: String) -> String {
        let safeEncodingB64 = b64String.replacingOccurrences(of: "+", with: "-")
        return safeEncodingB64.replacingOccurrences(of: "/", with: "_")
    }

    private func b64SafeEncodingToRegularEncoding(_ b64SafeEncodedString: String) -> String {
        let regularEncodingb64 = b64SafeEncodedString.replacingOccurrences(of: "-", with: "+")
        return regularEncodingb64.replacingOccurrences(of: "_", with: "/")
    }

    //link has shortened price and expiry and must be expanded
    func parseUniversalLink(url: String, prefix: String) -> SignedOrder? {
        guard url.count > prefix.count else { return nil }
        let linkInfo = b64SafeEncodingToRegularEncoding(url.substring(from: prefix.count))
        guard var linkBytes = Data(base64Encoded: linkInfo)?.array else { return nil }
        let encodingByte = linkBytes[0]
        if let format = LinkFormat(rawValue: encodingByte) {
            switch format {
            case .unassigned:
                return handleNormalLink(linkBytes: linkBytes)
            case .normal:
                //new link format, remove extra byte and continue
                linkBytes.remove(at: 0)
                return handleNormalLink(linkBytes: linkBytes)
            case .spawnable:
                return handleSpawnableLink(linkBytes: linkBytes)
            case .customizable:
                return handleSpawnableLink(linkBytes: linkBytes)
            case .nativeCurrencyLink:
                return handleNativeCurrencyDropLinks(linkBytes: linkBytes)
            }
        } else {
            return nil
        }

    }

    private func handleNormalLink(linkBytes: [UInt8]) -> SignedOrder? {
        let price = getPriceFromLinkBytes(linkBytes: linkBytes)
        let expiry = getExpiryFromLinkBytes(linkBytes: linkBytes)
        guard let contractAddress = getNonNullContractAddressFromLinkBytes(linkBytes: linkBytes) else { return nil }
        let tokenIndices = getTokenIndicesFromLinkBytes(linkBytes: linkBytes)
        guard let (v, r, s) = getVRSFromLinkBytes(linkBytes: linkBytes) else { return nil }
        let order = Order(
                price: price,
                indices: tokenIndices,
                expiry: expiry,
                contractAddress: contractAddress,
                count: BigUInt(tokenIndices.count),
                nonce: BigUInt(0),
                tokenIds: [],
                spawnable: false,
                nativeCurrencyDrop: false
        )
        let message = getMessageFromOrder(order: order)
        return SignedOrder(order: order, message: message, signature: "0x" + r + s + v)
    }

    //Note: native currency links can use szabo directly and
    //don't need to be compressed into szabo from wei and vice versa
    private func handleNativeCurrencyDropLinks(linkBytes: [UInt8]) -> SignedOrder? {
        var bytes = linkBytes
        bytes.remove(at: 0) //remove encoding byte
        let prefix = Array(bytes[0...7])
        let nonce = Array(bytes[8...11])
        let amount = Array(bytes[12...15])
        let expiry = Array(bytes[16...19])
        let contractBytes = Array(bytes[20...39])
        guard let contractAddress = AlphaWallet.Address(uncheckedAgainstNullAddress: Data(bytes: contractBytes).hex()) else { return nil }
        let v = String(bytes[104], radix: 16)
        let r = Data(bytes: Array(bytes[40...71])).hex()
        let s = Data(bytes: Array(bytes[72...103])).hex()
        let order = Order(
                price: BigUInt(0),
                indices: [UInt16](),
                expiry: BigUInt(Data(bytes: expiry)),
                contractAddress: contractAddress,
                count: BigUInt(Data(bytes: amount)),
                nonce: BigUInt(Data(bytes: nonce)),
                tokenIds: [BigUInt](),
                spawnable: false,
                nativeCurrencyDrop: true
        )
        let message = getMessageFromNativeCurrencyDropLink(
                prefix: prefix,
                nonce: nonce,
                amount: amount,
                expiry: expiry,
                contractAddress: contractBytes
        )
        return SignedOrder(order: order, message: message, signature: "0x" + r + s + v)
    }

    private func handleSpawnableLink(linkBytes: [UInt8]) -> SignedOrder? {
        var bytes = linkBytes
        bytes.remove(at: 0) //remove encoding byte
        let price = getPriceFromLinkBytes(linkBytes: bytes)
        let expiry = getExpiryFromLinkBytes(linkBytes: bytes)
        guard let contractAddress = getNonNullContractAddressFromLinkBytes(linkBytes: bytes) else { return nil }
        let tokenIds = getTokenIdsFromSpawnableLink(linkBytes: bytes)
        guard let (v, r, s) = getVRSFromLinkBytes(linkBytes: bytes) else { return nil }
        let order = Order(
            price: price,
            indices: [UInt16](),
            expiry: expiry,
            contractAddress: contractAddress,
            count: BigUInt(tokenIds.count),
            nonce: BigUInt(0),
            tokenIds: tokenIds,
            spawnable: true,
            nativeCurrencyDrop: false
        )
        let message = getMessageFromOrder(order: order)
        return SignedOrder(order: order, message: message, signature: "0x" + r + s + v)
    }

    private func getTokenIdsFromSpawnableLink(linkBytes: [UInt8]) -> [BigUInt] {
        let sigPos = linkBytes.count - 65; //the last 65 bytes are the signature params
        let tokenPos = 28 //tokens start at this byte
        let bytes = Array(linkBytes[tokenPos..<sigPos])
        let tokenIds = bytes.chunked(into: 32)
        return tokenIds.map { BigUInt(Data(bytes: $0)) }
    }

    //we used a special encoding so that one 16 bit number could represent either one token or two
    //this is for the purpose of keeping universal links as short as possible
    private func decodeTokenIndices(indices: [UInt16]) -> [UInt8] {
        var indicesBytes = [UInt8]()
        for i in 0..<indices.count {
            let index = indices[i]
            if index < 128 {
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

    //formats price and expiry to 4 bytes
    private func formatMessageForLink(signedOrder: SignedOrder) -> String {
        let indices = decodeTokenIndices(indices: signedOrder.order.indices)
        var messageWithSzabo = [UInt8]()
        //change from wei to szabo
        let priceSzabo = signedOrder.order.price / 1000000000000
        let priceBytes = padTo4Bytes(priceSzabo.serialize().bytes)
        let expiryBytes = padTo4Bytes(signedOrder.order.expiry.serialize().bytes)
        messageWithSzabo.append(LinkFormat.normal.rawValue)
        messageWithSzabo.append(contentsOf: priceBytes)
        messageWithSzabo.append(contentsOf: expiryBytes)
        messageWithSzabo.append(contentsOf: signedOrder.order.contractAddress.data.bytes)
        messageWithSzabo.append(contentsOf: indices)
        return Data(bytes: messageWithSzabo).hex()
    }

    private func formatMessageForLink721Ticket(signedOrder: SignedOrder) -> String {
        guard let tokenIds = signedOrder.order.tokenIds else { return "" }
        let tokens = tokenIds.map({ UniversalLinkHandler.padTo32($0.serialize().array) })
        var messageWithSzabo = [UInt8]()
        //change from wei to szabo
        let priceSzabo = signedOrder.order.price / 1000000000000
        let priceBytes = padTo4Bytes(priceSzabo.serialize().bytes)
        let expiryBytes = padTo4Bytes(signedOrder.order.expiry.serialize().bytes)
        messageWithSzabo.append(LinkFormat.spawnable.rawValue)
        messageWithSzabo.append(contentsOf: priceBytes)
        messageWithSzabo.append(contentsOf: expiryBytes)
        messageWithSzabo.append(contentsOf: signedOrder.order.contractAddress.data.bytes)
        for token in tokens {
            messageWithSzabo.append(contentsOf: token)
        }
        return Data(bytes: messageWithSzabo).hex()
    }

    private func padTo4Bytes(_ array: [UInt8]) -> [UInt8] {
        guard array.count != 4 else { return array }
        guard !array.isEmpty else { return [UInt8](repeating: 0, count: 4) }
        guard !(array.count > 4) else { return Array(array[0...3]) }
        var formattedArray = [UInt8]()
        let missingDigits = 4 - array.count
        for _ in 0..<missingDigits {
            formattedArray.append(0)
        }
        formattedArray.append(contentsOf: array)
        return formattedArray
    }

    private func getPriceFromLinkBytes(linkBytes: [UInt8]) -> BigUInt {
        let priceBytes = Array(linkBytes[0...3])
        let priceHex = Data(bytes: priceBytes).hex()
        guard let price = BigUInt(priceHex, radix: 16) else { return BigUInt(0) }
        return price * 1000000000000
    }

    private func getExpiryFromLinkBytes(linkBytes: [UInt8]) -> BigUInt {
        let expiryBytes = Array(linkBytes[4...7])
        let expiry = Data(bytes: expiryBytes).hex()
        guard let expiryBigUInt = BigUInt(expiry, radix: 16) else { return BigUInt(0) }
        return expiryBigUInt
    }

    //Specifically not for null (0x0...0) address
    private func getNonNullContractAddressFromLinkBytes(linkBytes: [UInt8]) -> AlphaWallet.Address? {
        let contractAddrBytes = Array(linkBytes[8...27])
        return AlphaWallet.Address(string: Data(bytes: contractAddrBytes).hex())
    }

    private func getTokenIndicesFromLinkBytes(linkBytes: [UInt8]) -> [UInt16] {
        let tokenLength = linkBytes.count - (65 + 20 + 8) - 1
        var tokenIndices = [UInt16]()
        var state: Int = 1
        var currentIndex: UInt16 = 0
        let tokenStart = 28

        for i in stride(from: tokenStart, through: tokenStart + tokenLength, by: 1) {
            let byte: UInt8 = linkBytes[i]
            switch state {
            case 1:
                //8th bit is equal to 128, if not set then it is only one token and will change the state
                if byte & (128) == 128 { //should be done with masks
                    currentIndex = UInt16((byte & 127)) << 8
                    state = 2
                } else {
                    tokenIndices.append(UInt16(byte))
                }
            case 2:
                currentIndex += UInt16(byte)
                tokenIndices.append(currentIndex)
                state = 1
            default:
                break
            }
        }
        return tokenIndices
    }

    private func getVRSFromLinkBytes(linkBytes: [UInt8]) -> (String, String, String)? {
        let signatureLength = 65
        guard linkBytes.count >= signatureLength else { return nil }
        var start = linkBytes.count - signatureLength
        let r = Data(bytes: Array(linkBytes[start...start + 31])).hex()
        start += 32
        let s = Data(bytes: Array(linkBytes[start...start + 31])).hex()
        var v = String(format: "%2X", linkBytes[linkBytes.count - 1]).trimmed
        if var vInt = Int(v) {
            if vInt < 5 {
                vInt += Int(EthereumSigner.vitaliklizeConstant)
                v = String(format: "%2X", vInt)
            }
        }
        return (v, r, s)
    }

    private func getMessageFromNativeCurrencyDropLink(
            prefix: [UInt8],
            nonce: [UInt8],
            amount: [UInt8],
            expiry: [UInt8],
            contractAddress: [UInt8]
    ) -> [UInt8] {
        var message = [UInt8]()
        message.append(contentsOf: prefix)
        message.append(contentsOf: nonce)
        message.append(contentsOf: amount)
        message.append(contentsOf: expiry)
        message.append(contentsOf: contractAddress)
        return message
    }

    //price and expiry need to be 32 bytes each
    private func getMessageFromOrder(order: Order) -> [UInt8] {
        var message = [UInt8]()
        //encode price and expiry first
        let priceBytes = UniversalLinkHandler.padTo32(order.price.serialize().array)
        message.append(contentsOf: priceBytes)
        let expiryBytes = UniversalLinkHandler.padTo32(order.expiry.serialize().array)
        message.append(contentsOf: expiryBytes)
        let contractBytes = order.contractAddress.eip55String.hexToBytes
        message.append(contentsOf: contractBytes)
        let indices = OrderHandler.uInt16ArrayToUInt8(arrayOfUInt16: order.indices)
        message.append(contentsOf: indices)
        return message
    }

    static func padTo32(_ buffer: [UInt8], to count: Int = 32) -> [UInt8] {
        let padCount = count - buffer.count
        var padded = buffer
        let padding: [UInt8] = Array(repeating: 0, count: padCount)
        padded.insert(contentsOf: padding, at: 0)
        return padded
    }

}

