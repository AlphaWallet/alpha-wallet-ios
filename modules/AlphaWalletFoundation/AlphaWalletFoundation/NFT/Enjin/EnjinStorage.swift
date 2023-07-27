//
//  EnjinStorage.swift
//  AlphaWalletFoundation-AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 09.02.2023.
//

import Foundation
import RealmSwift

public protocol EnjinStorage {
    func getEnjinToken(for tokenId: TokenId, server: RPCServer) async -> EnjinToken?
    func addOrUpdate(enjinTokens tokens: [EnjinToken], server: RPCServer)
}

extension RealmStore: EnjinStorage {
    public func getEnjinToken(for tokenId: TokenId, server: RPCServer) async -> EnjinToken? {
        var token: EnjinToken?
        await perform { realm in
            let primaryKey = EnjinTokenObject.generatePrimaryKey(
                server: server,
                tokenId: TokenIdConverter.toTokenIdSubstituted(string: tokenId.description))

            token = realm.object(ofType: EnjinTokenObject.self, forPrimaryKey: primaryKey)
                .flatMap { EnjinToken(object: $0) }
        }
        return token
    }

    public func addOrUpdate(enjinTokens tokens: [EnjinToken], server: RPCServer) {
        guard !tokens.isEmpty else { return }

        Task {
            await perform { realm in
                try? realm.safeWrite {
                    realm.delete(realm.objects(EnjinTokenObject.self))

                    let tokens = tokens.map { EnjinTokenObject(token: $0, server: server) }
                    realm.add(tokens, update: .all)
                }
            }
        }
    }
}

class EnjinTokenObject: Object {
    static func generatePrimaryKey(server: RPCServer, tokenId: String) -> String {
        return "\(server.chainID)-\(tokenId)"
    }

    @objc dynamic var primaryKey: String = ""
    @objc dynamic var tokenId: String = ""
    @objc dynamic var name: String = ""
    @objc dynamic var creator: String = ""
    @objc dynamic var meltValue: String = ""
    @objc dynamic var meltFeeRatio: Int = 0
    @objc dynamic var meltFeeMaxRatio: Int = 0
    @objc dynamic var supplyModel: String = ""
    @objc dynamic var totalSupply: String = ""
    @objc dynamic var circulatingSupply: String = ""
    @objc dynamic var reserve: String = ""
    @objc dynamic var transferable: String = ""
    @objc dynamic var nonFungible: Bool = false
    @objc dynamic var blockHeight: Int = 0
    @objc dynamic var mintableSupply: Double = 0
    @objc dynamic var value: Int = 0
    @objc dynamic var createdAt: String = ""
    @objc dynamic var transferFee: String = ""

    convenience init(token: EnjinToken, server: RPCServer) {
        self.init()
        primaryKey = EnjinTokenObject.generatePrimaryKey(server: server, tokenId: token.tokenId)
        tokenId = token.tokenId.description
        name = token.name
        creator = token.creator
        meltValue = token.meltValue
        meltFeeRatio = token.meltFeeRatio
        meltFeeMaxRatio = token.meltFeeMaxRatio
        supplyModel = token.supplyModel
        totalSupply = token.totalSupply
        circulatingSupply = token.circulatingSupply
        reserve = token.reserve
        transferable = token.transferable
        nonFungible = token.nonFungible
        blockHeight = token.blockHeight
        mintableSupply = token.mintableSupply
        value = token.value
        createdAt = token.createdAt
        transferFee = token.transferFee
    }

    override static func primaryKey() -> String? {
        return "primaryKey"
    }
}
