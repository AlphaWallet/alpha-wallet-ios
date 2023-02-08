//
//  OpenSeaStorage.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 09.02.2023.
//

import Foundation
import RealmSwift
import AlphaWalletOpenSea

public protocol OpenSeaStorage: AnyObject {
    func hasNftCollection(contract: AlphaWallet.Address, server: RPCServer) -> Bool
    func nftCollection(contract: AlphaWallet.Address, server: RPCServer) -> NftCollection?
}

extension RealmStore: OpenSeaStorage {

    public func hasNftCollection(contract: AlphaWallet.Address, server: RPCServer) -> Bool {
        return false
    }

    public func nftCollection(contract: AlphaWallet.Address, server: RPCServer) -> NftCollection? {
        return nil
    }

//    public func getEnjinToken(for tokenId: TokenId, owner: Wallet, server: RPCServer) -> EnjinToken? {
//        var token: EnjinToken?
//        performSync { realm in
//            let primaryKey = EnjinTokenObject.generatePrimaryKey(
//                fromContract: owner.address,
//                server: server,
//                tokenId: TokenIdConverter.toTokenIdSubstituted(string: tokenId.description))
//
//            token = realm.object(ofType: EnjinTokenObject.self, forPrimaryKey: primaryKey)
//                .flatMap { EnjinToken(object: $0) }
//        }
//        return token
//    }
//
//    public func addOrUpdate(enjinTokens tokens: [EnjinToken], owner: Wallet, server: RPCServer) {
//        guard !tokens.isEmpty else { return }
//
//        performSync { realm in
//            try? realm.safeWrite {
//                realm.delete(realm.objects(EnjinTokenObject.self))
//
//                let tokens = tokens.map { EnjinTokenObject(token: $0, owner: owner.address, server: server) }
//                realm.add(tokens, update: .all)
//            }
//        }
//    }
}

class PrimaryAssetContractObject: Object {
    @objc dynamic var primaryKey: String = ""
    @objc dynamic var address: String = ""
    @objc dynamic var chainId: Int = 0
    @objc dynamic var assetContractType: String = ""
    @objc dynamic var createdDate: String = ""
    @objc dynamic var name: String = ""
    @objc dynamic var nftVersion: String = ""
    @objc dynamic var schemaName: String = ""
    @objc dynamic var symbol: String = ""
    @objc dynamic var owner: String = ""
    @objc dynamic var totalSupply: String = ""
    @objc dynamic var contractDescription: String = ""
    @objc dynamic var externalLink: String = ""
    @objc dynamic var imageUrl: String = ""

    init(primaryAssetContract: PrimaryAssetContract, server: RPCServer) {
        super.init()
        primaryKey = "\(primaryAssetContract.address)-\(server.chainID)"
        self.chainId = server.chainID
        address = primaryAssetContract.address.eip55String
        assetContractType = primaryAssetContract.assetContractType
        createdDate = primaryAssetContract.createdDate
        name = primaryAssetContract.name
        nftVersion = primaryAssetContract.nftVersion
        schemaName = primaryAssetContract.schemaName
        symbol = primaryAssetContract.symbol
        owner = primaryAssetContract.owner
        totalSupply = primaryAssetContract.totalSupply
        contractDescription = primaryAssetContract.description
        externalLink = primaryAssetContract.externalLink
        imageUrl = primaryAssetContract.imageUrl
    }

    override static func primaryKey() -> String? {
        return "primaryKey"
    }
}

//inPrimaryAssetContractObject
class OpenSeaAssetTrait: Object {
    @objc dynamic var primaryKey: String = ""

    @objc dynamic var count: Int = 0
    @objc dynamic var type: String = ""
    @objc dynamic var value: String = ""

    init(trait: OpenSeaNonFungibleTrait, primaryKey: String) {
        self.primaryKey = primaryKey
        self.count = trait.count
        self.type = trait.type
        self.value = trait.value
    }

    override static func primaryKey() -> String? {
        return "primaryKey"
    }
}

class OpenSeaNftAssetObject: Object {
    @objc dynamic var primaryKey: String = ""

    @objc dynamic var tokenId: String = ""
    @objc dynamic var tokenType: String = ""
    @objc dynamic var value: String = ""
    @objc dynamic var contractName: String = ""
    @objc dynamic var decimals: Int = 0
    @objc dynamic var symbol: String = ""
    @objc dynamic var name: String = ""
    @objc dynamic var assetDescription: String = ""
    @objc dynamic var thumbnailUrl: String = ""
    @objc dynamic var imageUrl: String = ""
    @objc dynamic var previewUrl: String = ""
    @objc dynamic var contractImageUrl: String = ""
    @objc dynamic var imageOriginalUrl: String = ""
    @objc dynamic var externalLink: String = ""
    @objc dynamic var backgroundColor: String?
    var traits = List<OpenSeaAssetTrait>()
//    public var generationTrait: OpenSeaNonFungibleTrait? {
//        return traits.first { $0.type == OpenSeaNonFungible.generationTraitName }
//    }

//    public let tokenId: String
//    public let tokenType: NonFungibleFromJsonTokenType
//    public var value: BigInt
//    public let contractName: String
//    public let decimals: Int
//    public let symbol: String
//    public let name: String
//    public let description: String
//    public let thumbnailUrl: String
//    public let imageUrl: String
//    public let previewUrl: String
//    public let contractImageUrl: String
//    public let imageOriginalUrl: String
//    public let externalLink: String
//    public let backgroundColor: String?
//    public let traits: [OpenSeaNonFungibleTrait]
//    public var generationTrait: OpenSeaNonFungibleTrait? {
//        return traits.first { $0.type == OpenSeaNonFungible.generationTraitName }
//    }

//    public var creator: AssetCreator?
    @objc dynamic var collectionId: String = ""

    init(asset: NftAsset, server: RPCServer) {
        super.init()

        self.imageOriginalUrl = asset.imageOriginalUrl
        self.tokenId = asset.tokenId
        self.tokenType = asset.tokenType.rawValue
        self.value = asset.value.description
        self.contractName = asset.contractName
        self.decimals = asset.decimals
        self.symbol = asset.symbol
        self.name = asset.name
        self.assetDescription = asset.description
        self.thumbnailUrl = asset.thumbnailUrl
        self.imageUrl = asset.imageUrl
        self.contractImageUrl = asset.contractImageUrl
        self.externalLink = asset.externalLink
        self.backgroundColor = asset.backgroundColor
//        self.traits = traits
//        self.collectionCreatedDate = collectionCreatedDate
//        self.collectionDescription = collectionDescription
//        self.meltStringValue = meltStringValue
//        self.meltFeeRatio = meltFeeRatio
//        self.meltFeeMaxRatio = meltFeeMaxRatio
//        self.totalSupplyStringValue = totalSupplyStringValue
//        self.circulatingSupplyStringValue = circulatingSupplyStringValue
//        self.reserveStringValue = reserveStringValue
//        self.nonFungible = nonFungible
//        self.blockHeight = blockHeight
//        self.mintableSupply = mintableSupply
//        self.transferable = transferable
//        self.supplyModel = supplyModel
//        self.issuer = issuer
//        self.created = created
//        self.transferFee = transferFee
//        self.collection = collection
//        self.creator = creator

        traits.removeAll()
        traits.append(objectsIn: asset.traits.map{ OpenSeaAssetTrait(trait: $0, primaryKey: primaryKey) })
        self.collectionId = asset.collectionId
        self.previewUrl = asset.previewUrl
    }
}

class OpenSeaNftCollectionStatsObject: Object {
    @objc dynamic var primaryKey: String = ""

    @objc dynamic var oneDayVolume: Double = 0.0
    @objc dynamic var oneDayChange: Double = 0.0
    @objc dynamic var oneDaySales: Double = 0.0
    @objc dynamic var oneDayAveragePrice: Double = 0.0
    @objc dynamic var sevenDayVolume: Double = 0.0
    @objc dynamic var sevenDayChange: Double = 0.0
    @objc dynamic var sevenDaySales: Double = 0.0
    @objc dynamic var sevenDayAveragePrice: Double = 0.0

    @objc dynamic var thirtyDayVolume: Double = 0.0
    @objc dynamic var thirtyDayChange: Double = 0.0
    @objc dynamic var thirtyDaySales: Double = 0.0
    @objc dynamic var thirtyDayAveragePrice: Double = 0.0

    @objc dynamic var itemsCount: Double = 0.0
    @objc dynamic var totalVolume: Double = 0.0
    @objc dynamic var totalSales: Double = 0.0
    @objc dynamic var totalSupply: Double = 0.0

    @objc dynamic var owners: Int = 0
    @objc dynamic var averagePrice: Double = 0.0
    @objc dynamic var marketCap: Double = 0.0
    var floorPrice = RealmProperty<Double?>()
    @objc dynamic var numReports: Int = 0

    init(stats: NftCollectionStats, primaryKey: String) {
        super.init()
        self.primaryKey = primaryKey

        oneDayVolume = stats.oneDayVolume
        oneDayChange = stats.oneDayChange
        oneDaySales = stats.oneDaySales
        oneDayAveragePrice = stats.oneDayAveragePrice
        sevenDayVolume = stats.sevenDayVolume
        sevenDayChange = stats.sevenDayChange
        sevenDaySales = stats.sevenDaySales
        sevenDayAveragePrice = stats.sevenDayAveragePrice
        thirtyDayVolume = stats.thirtyDayVolume
        thirtyDayChange = stats.thirtyDayChange
        thirtyDaySales = stats.thirtyDaySales
        thirtyDayAveragePrice = stats.thirtyDayAveragePrice
        itemsCount = stats.itemsCount
        totalVolume = stats.totalVolume
        totalSales = stats.totalSales
        totalSupply = stats.totalSupply
        owners = stats.owners
        averagePrice = stats.averagePrice
        marketCap = stats.marketCap
        floorPrice.value = stats.floorPrice
        numReports = stats.numReports
    }

    override static func primaryKey() -> String? {
        return "primaryKey"
    }

}

class OpenSeaNftCollectionObject: Object {
    @objc dynamic var primaryKey: String = ""

    @objc dynamic var id: String = ""
    @objc dynamic var ownedAssetCount: Int = 0
    @objc dynamic var wikiUrl: String?
    @objc dynamic var instagramUsername: String?
    @objc dynamic var twitterUsername: String?
    @objc dynamic var discordUrl: String?
    @objc dynamic var telegramUrl: String?
    @objc dynamic var shortDescription: String?
    @objc dynamic var bannerImageUrl: String?
    @objc dynamic var chatUrl: String?
    @objc dynamic var createdDate: Date?
    @objc dynamic var defaultToFiat: Bool = false
    @objc dynamic var descriptionString: String = ""
    @objc dynamic var stats: OpenSeaNftCollectionStatsObject?
    @objc dynamic var name: String = ""
    @objc dynamic var externalUrl: String?
    var contracts = List<PrimaryAssetContractObject>()
    @objc dynamic var bannerUrl: String?


//    public let id: String
//    public let ownedAssetCount: Int
//    public let wikiUrl: String?
//    public let instagramUsername: String?
//    public let twitterUsername: String?
//    public let discordUrl: String?
//    public let telegramUrl: String?
//    public let shortDescription: String?
//    public let bannerImageUrl: String?
//    public let chatUrl: String?
//    public let createdDate: String?
//    public let defaultToFiat: Bool
//    public let descriptionString: String
//    public var stats: NftCollectionStats?
//    public let name: String
//    public let externalUrl: String?
//    public let contracts: [PrimaryAssetContract]
//    public let bannerUrl: String?
//    static func generatePrimaryKey(fromContract contract: AlphaWallet.Address, server: RPCServer, tokenId: String) -> String {
//        return "\(contract.eip55String)-\(server.chainID)-\(tokenId)"
//    }
//
//    @objc dynamic var primaryKey: String = ""
//    @objc dynamic var tokenId: String = ""
//    @objc dynamic var name: String = ""
//    @objc dynamic var creator: String = ""
//    @objc dynamic var meltValue: String = ""
//    @objc dynamic var meltFeeRatio: Int = 0
//    @objc dynamic var meltFeeMaxRatio: Int = 0
//    @objc dynamic var supplyModel: String = ""
//    @objc dynamic var totalSupply: String = ""
//    @objc dynamic var circulatingSupply: String = ""
//    @objc dynamic var reserve: String = ""
//    @objc dynamic var transferable: String = ""
//    @objc dynamic var nonFungible: Bool = false
//    @objc dynamic var blockHeight: Int = 0
//    @objc dynamic var mintableSupply: Double = 0
//    @objc dynamic var value: Int = 0
//    @objc dynamic var createdAt: String = ""
//    @objc dynamic var transferFee: String = ""


    convenience init(collection: NftCollection, server: RPCServer) {
        self.init()
        primaryKey = "\(id)-\(server.chainID)"
        id = collection.id

        ownedAssetCount = collection.ownedAssetCount
        wikiUrl = collection.wikiUrl
        instagramUsername = collection.instagramUsername
        twitterUsername = collection.twitterUsername
        discordUrl = collection.discordUrl
        telegramUrl = collection.telegramUrl
        shortDescription = collection.shortDescription
        bannerImageUrl = collection.bannerImageUrl
        chatUrl = collection.chatUrl
        createdDate = collection.createdDate
        defaultToFiat = collection.defaultToFiat
        descriptionString = collection.descriptionString
//        @objc dynamic var stats: NftCollectionStats?
        name = collection.name
        externalUrl = collection.externalUrl
    //    @objc dynamic var contracts: [PrimaryAssetContract]
//        var contracts = List<PrimaryAssetContractObject>()
        contracts.removeAll()
        contracts.append(objectsIn: collection.contracts.map { PrimaryAssetContractObject(primaryAssetContract: $0, server: server) })
        bannerUrl = collection.bannerUrl


//        primaryKey = EnjinTokenObject.generatePrimaryKey(fromContract: owner, server: server, tokenId: token.tokenId)
//        tokenId = token.tokenId.description
//        name = token.name
//        creator = token.creator
//        meltValue = token.meltValue
//        meltFeeRatio = token.meltFeeRatio
//        meltFeeMaxRatio = token.meltFeeMaxRatio
//        supplyModel = token.supplyModel
//        totalSupply = token.totalSupply
//        circulatingSupply = token.circulatingSupply
//        reserve = token.reserve
//        transferable = token.transferable
//        nonFungible = token.nonFungible
//        blockHeight = token.blockHeight
//        mintableSupply = token.mintableSupply
//        value = token.value
//        createdAt = token.createdAt
//        transferFee = token.transferFee
    }

    override static func primaryKey() -> String? {
        return "primaryKey"
    }
}
