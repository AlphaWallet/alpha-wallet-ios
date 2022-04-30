//
//  PrimaryAssetContract.swift
//  AlphaWalletOpenSea
//
//  Created by Vladyslav Shepitko on 31.01.2022.
//

import Foundation
import AlphaWalletAddress
import SwiftyJSON

public struct PrimaryAssetContract: Codable {
    let address: AlphaWallet.Address
    let assetContractType: String
    let createdDate: String
    let name: String
    let nftVersion: String
    let schemaName: String
    let symbol: String
    let owner: String
    let totalSupply: String
    let description: String
    let externalLink: String
    let imageUrl: String

    init(json: JSON) throws {
        guard let address = AlphaWallet.Address(string: json["address"].stringValue) else {
            throw OpenSeaAssetDecoder.DecoderError.jsonInvalidError
        }

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