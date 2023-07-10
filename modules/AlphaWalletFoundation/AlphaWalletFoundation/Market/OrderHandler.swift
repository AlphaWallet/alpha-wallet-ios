// Copyright © 2018 Stormbird PTE. LTD.

import BigInt

public struct Order {
    public var price: BigUInt
    public var indices: [UInt16]
    public var expiry: BigUInt
    public var contractAddress: AlphaWallet.Address
    public var count: BigUInt
    public var nonce: BigUInt
    public var tokenIds: [BigUInt]?
    public var spawnable: Bool
    public var nativeCurrencyDrop: Bool

    public init(price: BigUInt, indices: [UInt16], expiry: BigUInt, contractAddress: AlphaWallet.Address, count: BigUInt, nonce: BigUInt, tokenIds: [BigUInt]?, spawnable: Bool, nativeCurrencyDrop: Bool) {
        self.price = price
        self.indices = indices
        self.expiry = expiry
        self.contractAddress = contractAddress
        self.count = count
        self.nonce = nonce
        self.tokenIds = tokenIds
        self.spawnable = spawnable
        self.nativeCurrencyDrop = nativeCurrencyDrop
    }
}

public struct SignedOrder {
    public var order: Order
    public var message: [UInt8]
    public var signature: String

    public init(order: Order, message: [UInt8], signature: String) {
        self.order = order
        self.message = message
        self.signature = signature
    }
}

extension BinaryInteger {
    public var data: Data {
        var source = self
        return Data(bytes: &source, count: MemoryLayout<Self>.size)
    }
}

extension Data {
    public var array: [UInt8] {
        return Array(self)
    }
}

public class OrderHandler {
    private let keystore: Keystore
    private let prompt: String

    public init(keystore: Keystore, prompt: String) {
        self.keystore = keystore
        self.prompt = prompt
    }

    public func signOrders(orders: [Order], account: AlphaWallet.Address, tokenType: TokenType) async throws -> [SignedOrder] {
        let messages = createMessagesFromOrders(orders: orders, tokenType: tokenType)
        return try await bulkSignOrders(messages: messages, account: account, orders: orders)
    }

    private func createMessagesFromOrders(orders: [Order], tokenType: TokenType) -> [Data] {
        var messages = [Data]()
        switch tokenType {
        case .erc721ForTickets:
            for order in orders {
                let message: [UInt8] = encodeMessageForTrade(
                        price: order.price,
                        expiryBuffer: order.expiry,
                        tokenIds: order.tokenIds ?? [BigUInt](),
                        contractAddress: order.contractAddress
                )
                messages.append(Data(bytes: message))
            }
        case .erc875:
            for order in orders {
                let message: [UInt8] = encodeMessageForTrade(
                        price: order.price,
                        expiryBuffer: order.expiry,
                        indices: order.indices,
                        contractAddress: order.contractAddress
                )
                messages.append(Data(bytes: message))
            }
        case .erc721, .erc1155, .nativeCryptocurrency, .erc20:
            break
        }
        return messages
    }

    private func bulkSignOrders(messages: [Data], account: AlphaWallet.Address, orders: [Order]) async throws -> [SignedOrder] {
        var signedOrders = [SignedOrder]()
        let signatures = try await keystore.signMessageBulk(messages, for: account, prompt: prompt).get()
        for i in 0..<signatures.count {
            let signedOrder = SignedOrder(
                    order: orders[i],
                    message: messages[i].bytes,
                    signature: signatures[i].hexString
            )
            signedOrders.append(signedOrder)
        }
        return signedOrders
    }

    public func encodeMessageForTrade(
            price: BigUInt,
            expiryBuffer: BigUInt,
            indices: [UInt16],
            contractAddress: AlphaWallet.Address
    ) -> [UInt8] {
        let arrayLength: Int = 84 + indices.count * 2
        var buffer = [UInt8]()
        buffer.reserveCapacity(arrayLength)
        let priceInWei = UniversalLinkHandler.padTo32(Array(price.serialize()))
        let expiry = UniversalLinkHandler.padTo32(Array(expiryBuffer.serialize()))
        buffer.append(contentsOf: priceInWei)
        buffer.append(contentsOf: expiry)
        //no leading zeros issue here
        buffer.append(contentsOf: contractAddress.eip55String.hexToBytes)
        let tokensUint8 = OrderHandler.uInt16ArrayToUInt8(arrayOfUInt16: indices)
        buffer.append(contentsOf: tokensUint8)
        return buffer
    }

    public func encodeMessageForTrade(
            price: BigUInt,
            expiryBuffer: BigUInt,
            tokenIds: [BigUInt],
            contractAddress: AlphaWallet.Address
    ) -> [UInt8] {
        let arrayLength: Int = 84 + tokenIds.count * 32
        var buffer = [UInt8]()
        buffer.reserveCapacity(arrayLength)
        let priceInWei = Array(price.serialize())
        let expiry = Array(expiryBuffer.serialize())
        buffer.append(contentsOf: UniversalLinkHandler.padTo32(priceInWei))
        buffer.append(contentsOf: UniversalLinkHandler.padTo32(expiry))
        buffer.append(contentsOf: contractAddress.eip55String.hexToBytes)
        for token in tokenIds {
            buffer.append(contentsOf: UniversalLinkHandler.padTo32(token.serialize().array))
        }
        return buffer
    }

    public static func uInt16ArrayToUInt8(arrayOfUInt16: [UInt16]) -> [UInt8] {
        var arrayOfUint8 = [UInt8]()
        for i in 0..<arrayOfUInt16.count {
            let UInt8ArrayPair = arrayOfUInt16[i].bigEndian.data.array
            arrayOfUint8.append(UInt8ArrayPair[0])
            arrayOfUint8.append(UInt8ArrayPair[1])
        }
        return arrayOfUint8
    }

}

fileprivate extension Data {
    //TODO: Duplicated here when we break out `AlphaWalletTrustWalletCoreExtensions` pod. To de-dup anytime
    var hexString: String {
        return map({ String(format: "%02x", $0) }).joined()
    }
}
