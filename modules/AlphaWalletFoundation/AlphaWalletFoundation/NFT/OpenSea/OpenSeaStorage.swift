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
    func nftCollections(excluding: [String]) -> [NftCollection]

    func addOrUpdate(assets: [NftCollectionAssetsResponse], server: RPCServer)
//    func addOrUpdate(collection: AlphaWalletOpenSea.NftCollection, server: RPCServer)
    func deleteAllExcluding(assets: [NftCollectionAssetsResponse], server: RPCServer)
}

extension NftCollection {
    init(object: OpenSeaNftCollectionObject) {
        id = object.id
        ownedAssetCount = object.ownedAssetCount
        wikiUrl = object.wikiUrl
        instagramUsername = object.instagramUsername
        twitterUsername = object.twitterUsername
        discordUrl = object.discordUrl
        telegramUrl = object.telegramUrl
        shortDescription = object.shortDescription
        bannerImageUrl = object.bannerImageUrl
        chatUrl = object.chatUrl
        createdDate = object.createdDate
        defaultToFiat = object.defaultToFiat
        descriptionString = object.descriptionString
        stats = object.stats.flatMap { NftCollectionStats(object: $0) }
        name = object.name
        externalUrl = object.externalUrl
        contracts = object.contracts.map { PrimaryAssetContract(object: $0) }
        bannerUrl = object.bannerUrl
    }
}

extension NftAsset2_0 {
    init?(object: OpenSeaNftAssetObject) {
        guard let assetContract = object.assetContract else { return nil }
        tokenId = object.tokenId
        backgroundColor = object.backgroundColor
        imageUrl = object.imageUrl
        previewUrl = object.previewUrl
        thumbnailUrl = object.thumbnailUrl
        imageOriginalUrl = object.imageOriginalUrl
        animationUrl = object.animationUrl
        name = object.name
        description = object.assetDescription
        externalLink = object.externalLink
        self.assetContract = PrimaryAssetContract(object: assetContract)
//        collection = NftCollection(json: json["collection"], contracts: [assetContract])
//        traits = json["traits"].arrayValue.compactMap { OpenSeaNonFungibleTrait(json: $0) }
//        creator = AssetCreator(json: json["creator"])
        fatalError()
    }
}

extension RealmStore: OpenSeaStorage {

    public func hasNftCollection(contract: AlphaWallet.Address, server: RPCServer) -> Bool {
        return false
    }

    static func nftCollectionPredicate(server: RPCServer, contract: AlphaWallet.Address) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "chainId = \(server.chainID)"),
            NSPredicate(format: "ANY contracts.address == '\(contract.eip55String)'")
        ])
    }

    static func nftAssetsPredicate(server: RPCServer, contract: AlphaWallet.Address) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "assetContract != nil"),
            NSPredicate(format: "assetContract.chainId = \(server.chainID)"),
            NSPredicate(format: "assetContract.address == '\(contract.eip55String)'")
        ])
    }

    public func nftAssets(contract: AlphaWallet.Address, server: RPCServer) -> [NftAsset2_0] {
        var assets: [NftAsset2_0] = []
        performSync { realm in
            try? realm.safeWrite {
                assets = Array(realm.objects(OpenSeaNftAssetObject.self)
                    .filter(RealmStore.nftAssetsPredicate(server: server, contract: contract))
                    .compactMap { NftAsset2_0(object: $0) })
            }
        }

        return assets
    }

    public func nftCollection(contract: AlphaWallet.Address, server: RPCServer) -> NftCollection? {
        var collection: NftCollection?
        performSync { realm in
            try? realm.safeWrite {
                collection = realm.objects(OpenSeaNftCollectionObject.self)
                    .filter(RealmStore.nftCollectionPredicate(server: server, contract: contract))
                    .first
                    .flatMap { NftCollection(object: $0) }
            }
        }

        return collection
    }

//    public func addOrUpdate(collection: AlphaWalletOpenSea.NftCollection, server: RPCServer) {
//        performSync { realm in
//            try? realm.safeWrite {
//                var contracts: [PrimaryAssetContractObject] = []
//                for contract in collection.contracts {
//                    let object = PrimaryAssetContractObject(primaryAssetContract: contract, server: server)
//                    realm.add(object, update: .all)
//                    contracts += [object]
//                }
//
//                let collectionObject = OpenSeaNftCollectionObject(collection: collection, server: server)
//                collectionObject.contracts.removeAll()
//                collectionObject.contracts.append(objectsIn: contracts)
//                collectionObject.stats = collection.stats.flatMap {
//                    OpenSeaNftCollectionStatsObject(stats: $0, primaryKey: collectionObject.primaryKey)
//                }
//
//                realm.add(collectionObject, update: .all)
//            }
//        }
//    }

    public func deleteAllExcluding(assets: [NftCollectionAssetsResponse], server: RPCServer) {
        performSync { realm in
            try? realm.safeWrite {
                let collections = assets.map { OpenSeaNftCollectionObject.primaryKey(id: $0.collection.id, server: server) }
                let contracts = assets.flatMap { $0.assets.map { PrimaryAssetContractObject.privateKey(address: $0.assetContract.address, server: server) } }
                let assets = assets.flatMap { $0.assets.map { OpenSeaNftAssetObject.privateKey(address: $0.assetContract.address, tokenId: $0.tokenId, server: server) } }

                let collectionsToDelete = realm.objects(OpenSeaNftCollectionObject.self)
                    .filter { !collections.contains($0.primaryKey) }

                let contractsToDelete = realm.objects(PrimaryAssetContractObject.self)
                    .filter { !contracts.contains($0.primaryKey) }

                let assetsToDelete = realm.objects(OpenSeaNftAssetObject.self)
                    .filter { !assets.contains($0.primaryKey) }

                realm.delete(collectionsToDelete)
                realm.delete(contractsToDelete)
                realm.delete(assetsToDelete)
            }
        }
    }

    public func addOrUpdate(assets: [NftCollectionAssetsResponse], server: RPCServer) {
        performSync { realm in
            try? realm.safeWrite {
                for asset in assets {
                    var contracts: [PrimaryAssetContractObject] = []
                    for contract in asset.collection.contracts {
//                        let contractPk = PrimaryAssetContractObject.privateKey(address: contract.address, server: server)
//
//                        if let object = realm.object(ofType: PrimaryAssetContractObject.self, forPrimaryKey: contractPk) {
//                            contracts += [object]
//                        } else {
                        let object = PrimaryAssetContractObject(primaryAssetContract: contract, server: server)
                        realm.add(object, update: .all)
//                            contracts += [object]
//                        }
                    }

//                    let collection: OpenSeaNftCollectionObject
//                    let collectionPk = OpenSeaNftCollectionObject.primaryKey(id: asset.collection.id, server: server)
//                    if let object = realm.object(ofType: OpenSeaNftCollectionObject.self, forPrimaryKey: collectionPk) {
////                        if object.contracts.contains(where: { $0.primaryKey == contract.primaryKey }) {
////                            //no-op
////                        } else {
////                            object.contracts.append(contract)
////                        }
//                        collection = object
//                    } else {
                    let collectionObject = OpenSeaNftCollectionObject(collection: asset.collection, server: server)
                    collectionObject.contracts.removeAll()
                    collectionObject.contracts.append(objectsIn: contracts)
                    collectionObject.stats = asset.collection.stats.flatMap {
                        OpenSeaNftCollectionStatsObject(stats: $0, primaryKey: collectionObject.primaryKey)
                    }

                    realm.add(collectionObject, update: .all)

                    for asset in asset.assets {
//                        let contractPk = PrimaryAssetContractObject.privateKey(address: asset.assetContract.address, server: server)
//                        let contract: PrimaryAssetContractObject
//                        if let object = realm.object(ofType: PrimaryAssetContractObject.self, forPrimaryKey: contractPk) {
//                            contract = object
//                        } else {
//                            let object = PrimaryAssetContractObject(primaryAssetContract: asset.assetContract, server: server)
//                            realm.add(object, update: .all)
//                            contract = object
//                        }
//
//                        let collection: OpenSeaNftCollectionObject
//                        let collectionPk = OpenSeaNftCollectionObject.primaryKey(id: asset.collection.id, server: server)
//                        if let object = realm.object(ofType: OpenSeaNftCollectionObject.self, forPrimaryKey: collectionPk) {
//                            collection = object
//                        } else {
//                            let object = OpenSeaNftCollectionObject(collection: asset.collection, server: server)
////                            object.contracts.append(objectsIn: contracts)
//                            realm.add(object, update: .all)
//
//                            collection = object
//                        }
//
//                        let assetPk = OpenSeaNftAssetObject.privateKey(address: asset.assetContract.address, tokenId: asset.tokenId, server: server)
//                        if let object = realm.object(ofType: OpenSeaNftAssetObject.self, forPrimaryKey: assetPk) {
////                            realm.add(<#T##object: Object##Object#>, update: <#T##Realm.UpdatePolicy#>)
//                        } else {
//                            let object = OpenSeaNftAssetObject(asset: asset, address: asset.assetContract.address, server: server)
//                            realm.add(object, update: .all)
//                        }

//                        let assetContractObject = PrimaryAssetContractObject(primaryAssetContract: asset.assetContract, server: server)
//                        realm.add(assetContractObject, update: .all)
//
//                        let collectionObject = OpenSeaNftCollectionObject(collection: asset.collection, server: server)
//                        collectionObject.contracts.removeAll()
//                        collectionObject.contracts.append(assetContractObject)
//
//                        realm.add(collectionObject, update: .all)

                        let assetObject = OpenSeaNftAssetObject(asset: asset, address: asset.assetContract.address, server: server)
                        if let assetContractObject = contracts.first(where: { $0.address == asset.assetContract.address.eip55String }) {
                            assetObject.assetContract = assetContractObject
                        } else {
                            //can't be
                        }

                        realm.add(assetObject, update: .all)
                    }
                }
            }
        }
    }

    public func nftCollections(excluding: [String]) -> [NftCollection] {
        var collections: [NftCollection] = []
        performSync { _ in
            
        }
        return collections
    }

    public func remove(collection: [AlphaWalletOpenSea.NftCollection]) {

    }

//    public func addOrUpdate(collections: [NftCollectionAssetsResponse]) {
//        guard !collections.isEmpty else { return }
//
//        performSync { realm in
//            try? realm.safeWrite {
//                for each in collections {
//
//                }
//            }
//        }
//    }

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
extension PrimaryAssetContract {

    init(object: PrimaryAssetContractObject) {
        address = AlphaWallet.Address(string: object.address)!
        assetContractType = object.assetContractType
        createdDate = object.createdDate
        name = object.name
        nftVersion = object.nftVersion
        schemaName = object.schemaName
        symbol = object.symbol
        owner = object.owner
        totalSupply = object.totalSupply
        description = object.contractDescription
        externalLink = object.externalLink
        imageUrl = object.imageUrl
    }
}

class PrimaryAssetContractObject: Object {
    static func privateKey(address: AlphaWallet.Address, server: RPCServer) -> String {
        "\(address.eip55String)-\(server.chainID)"
    }

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
        primaryKey = PrimaryAssetContractObject.privateKey(address: primaryAssetContract.address, server: server)
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
    static func privateKey(address: AlphaWallet.Address, tokenId: String, server: RPCServer) -> String {
        "\(address.eip55String)-\(tokenId)-\(server.chainID)"
    }

    @objc dynamic var primaryKey: String = ""
    @objc dynamic var tokenId: String = ""
    @objc dynamic var backgroundColor: String?
    @objc dynamic var imageUrl: String = ""
    @objc dynamic var previewUrl: String = ""
    @objc dynamic var thumbnailUrl: String?
    @objc dynamic var imageOriginalUrl: String?
    @objc dynamic var animationUrl: String?
    @objc dynamic var name: String = ""
    @objc dynamic var assetDescription: String?
    @objc dynamic var externalLink: String?
    @objc var assetContract: PrimaryAssetContractObject?
    var traits = List<OpenSeaAssetTrait>()

//    @objc var creator: AssetCreator?
    @objc dynamic var collectionId: String = ""

    init(asset: AlphaWalletOpenSea.NftAssetResponse, address: AlphaWallet.Address, server: RPCServer) {
        super.init()
        self.primaryKey = OpenSeaNftAssetObject.privateKey(address: address, tokenId: asset.tokenId, server: server)

        self.tokenId = asset.tokenId
        self.backgroundColor = asset.backgroundColor
        self.imageUrl = asset.imageUrl
        self.previewUrl = asset.previewUrl
        self.thumbnailUrl = asset.thumbnailUrl
        self.imageOriginalUrl = asset.imageOriginalUrl
        self.animationUrl = asset.animationUrl
        self.name = asset.name
        self.assetDescription = asset.description
        self.externalLink = asset.externalLink

        self.collectionId = asset.collection.id

//        self.tokenType = asset.tokenType.rawValue
//        self.value = asset.value.description
//        self.contractName = asset.contractName
//        self.decimals = asset.decimals
//        self.symbol = asset.symbol




//        self.contractImageUrl = asset.contractImageUrl


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

//        traits.removeAll()
//        traits.append(objectsIn: asset.traits.map { OpenSeaAssetTrait(trait: $0, primaryKey: primaryKey) })


    }
}

//public struct AssetCreator: Codable {
//    public let contractAddress: AlphaWallet.Address
//    public let config: String
//    public let profileImageUrl: URL?
//    public let user: String?
//
//    init?(json: JSON) {
//        guard let address = AlphaWallet.Address(string: json["address"].stringValue) else { return nil }
//
//        self.contractAddress = address
//        self.config = json["config"].stringValue
//        self.profileImageUrl = json["profile_img_url"].string.flatMap { URL(string: $0.trimmed) }
//        self.user = json["user"]["username"].string
//    }
//}

extension NftCollectionStats {
    init(object: OpenSeaNftCollectionStatsObject) {
        oneDayVolume = object.oneDayVolume
        oneDayChange = object.oneDayChange
        oneDaySales = object.oneDaySales
        oneDayAveragePrice = object.oneDayAveragePrice
        sevenDayVolume = object.sevenDayVolume
        sevenDayChange = object.sevenDayChange
        sevenDaySales = object.sevenDaySales
        sevenDayAveragePrice = object.sevenDayAveragePrice
        thirtyDayVolume = object.thirtyDayVolume
        thirtyDayChange = object.thirtyDayChange
        thirtyDaySales = object.thirtyDaySales
        thirtyDayAveragePrice = object.thirtyDayAveragePrice
        itemsCount = object.itemsCount
        totalVolume = object.totalVolume
        totalSales = object.totalSales
        totalSupply = object.totalSupply
        owners = object.owners
        averagePrice = object.averagePrice
        marketCap = object.marketCap
        floorPrice = object.floorPrice.value
        numReports = object.numReports
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
    static func primaryKey(id: String, server: RPCServer) -> String {
        return "\(id)-\(server.chainID)"
    }

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
//        contracts.removeAll()
//        contracts.append(objectsIn: collection.contracts.map { PrimaryAssetContractObject(primaryAssetContract: $0, server: server) })
        bannerUrl = collection.bannerUrl
    }

    override static func primaryKey() -> String? {
        return "primaryKey"
    }
}
