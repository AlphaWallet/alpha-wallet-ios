//
//  CollectionKey.swift
//  AlphaWalletOpenSea
//
//  Created by Hwee-Boon Yar on Apr/30/22.
//

import AlphaWalletAddress
import Foundation

public enum CollectionKey: Hashable {
    case address(AlphaWallet.Address)
    case collectionId(String)
}
