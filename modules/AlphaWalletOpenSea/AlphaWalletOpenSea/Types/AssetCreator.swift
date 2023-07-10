//
//  AssetCreator.swift
//  AlphaWalletOpenSea
//
//  Created by Hwee-Boon Yar on Apr/30/22.
//

import Foundation
import AlphaWalletAddress
import SwiftyJSON

public struct AssetCreator: Codable {
    public let contractAddress: AlphaWallet.Address
    public let config: String
    public let profileImageUrl: URL?
    public let user: String?

    public init(json: JSON) throws {
        guard let address = AlphaWallet.Address(string: json["address"].stringValue) else {
            throw NftAssetsPageDecoder.DecoderError.jsonInvalidError
        }
        self.contractAddress = address
        self.config = json["config"].stringValue
        self.profileImageUrl = json["profile_img_url"].string.flatMap { URL(string: $0.trimmed) }
        self.user = json["user"]["username"].string
    }
}
