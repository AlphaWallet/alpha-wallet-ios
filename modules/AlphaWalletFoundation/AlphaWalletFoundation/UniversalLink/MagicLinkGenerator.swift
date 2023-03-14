//
//  MagicLinkGenerator.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 01.03.2023.
//

import Foundation
import BigInt

public class MagicLinkGenerator {
    private let keystore: Keystore
    private let session: WalletSession
    private let prompt: String

    public init(keystore: Keystore, session: WalletSession, prompt: String) {
        self.keystore = keystore
        self.session = session
        self.prompt = prompt
    }

    public func generateTransferLink(magicLinkData: MagicLinkGenerator.MagicLinkData,
                                     linkExpiryDate: Date) async throws -> String {

        let order = Order(
            price: BigUInt(0),
            indices: magicLinkData.indices,
            expiry: BigUInt(Int(linkExpiryDate.timeIntervalSince1970)),
            contractAddress: magicLinkData.contractAddress,
            count: BigUInt(magicLinkData.indices.count),
            nonce: BigUInt(0),
            tokenIds: magicLinkData.tokenIds,
            spawnable: false,
            nativeCurrencyDrop: false)

        let signedOrders = try await OrderHandler(keystore: keystore, prompt: prompt).signOrders(
            orders: [order],
            account: session.account.address,
            tokenType: magicLinkData.tokenType)

        return UniversalLinkHandler(server: session.server).createUniversalLink(
            signedOrder: signedOrders[0],
            tokenType: magicLinkData.tokenType)
    }

        //note that the price must be in szabo for a sell link, price must be rounded
    public func generateSellLink(magicLinkData: MagicLinkGenerator.MagicLinkData,
                                 linkExpiryDate: Date,
                                 ethCost: Double) async throws -> String {

        let ethCostRoundedTo5dp = String(format: "%.5f", Float(String(ethCost))!)
        let cost = Decimal(string: ethCostRoundedTo5dp)! * Decimal(string: "1000000000000000000")!
        let wei = BigUInt(cost.description)!

        let order = Order(
            price: wei,
            indices: magicLinkData.indices,
            expiry: BigUInt(Int(linkExpiryDate.timeIntervalSince1970)),
            contractAddress: magicLinkData.contractAddress,
            count: BigUInt(magicLinkData.indices.count),
            nonce: BigUInt(0),
            tokenIds: magicLinkData.tokenIds,
            spawnable: false,
            nativeCurrencyDrop: false)

        let signedOrders = try await OrderHandler(keystore: keystore, prompt: prompt).signOrders(
            orders: [order],
            account: session.account.address,
            tokenType: magicLinkData.tokenType)

        return UniversalLinkHandler(server: session.server).createUniversalLink(
            signedOrder: signedOrders[0],
            tokenType: magicLinkData.tokenType)
    }
}

extension MagicLinkGenerator {
    public struct MagicLinkData {
        public let tokenIds: [TokenId]
        public let indices: [UInt16]
        public let tokenType: TokenType
        public let contractAddress: AlphaWallet.Address
        public let count: Int

        public init(tokenIds: [TokenId], indices: [UInt16], tokenType: TokenType, contractAddress: AlphaWallet.Address, count: Int) {
            self.tokenIds = tokenIds
            self.indices = indices
            self.tokenType = tokenType
            self.contractAddress = contractAddress
            self.count = count
        }
    }
}
