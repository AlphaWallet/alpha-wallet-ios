//
//  NftCollectionIdentifier.swift
//  AlphaWalletOpenSea
//
//  Created by Hwee-Boon Yar on Apr/30/22.
//

import Foundation
import AlphaWalletAddress

enum NftCollectionIdentifier: Hashable {
    case address(AlphaWallet.Address)
    case collectionId(String)
}
