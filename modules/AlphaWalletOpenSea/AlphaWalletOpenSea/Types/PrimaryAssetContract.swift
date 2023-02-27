//
//  PrimaryAssetContract.swift
//  AlphaWalletOpenSea
//
//  Created by Vladyslav Shepitko on 31.01.2022.
//

import Foundation
import AlphaWalletAddress
import SwiftyJSON

//TODO: rename with NftAssetContract
public struct PrimaryAssetContract: Codable {
    public let address: AlphaWallet.Address
    public let assetContractType: String
    public let createdDate: String
    public let name: String
    public let nftVersion: String
    public let schemaName: String
    public let symbol: String
    public let owner: String
    public let totalSupply: String
    public let description: String
    public let externalLink: String
    public let imageUrl: String

    init?(json: JSON) {
        guard let address = AlphaWallet.Address(string: json["address"].stringValue) else { return nil }

        self.address = address
        assetContractType = json["asset_contract_type"].stringValue
        createdDate = json["created_date"].stringValue
        name = json["name"].stringValue
        nftVersion = json["nft_version"].stringValue
        schemaName = json["schema_name"].stringValue
        symbol = json["symbol"].stringValue
        owner = json["owner"].stringValue
        totalSupply = json["total_supply"].stringValue
        description = json["description"].stringValue
        externalLink = json["external_link"].stringValue
        imageUrl = json["image_url"].stringValue
    }
}
