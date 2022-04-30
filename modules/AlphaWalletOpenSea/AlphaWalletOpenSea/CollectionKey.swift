//
//  CollectionKey.swift
//  AlphaWalletOpenSea
//
//  Created by Hwee-Boon Yar on Apr/30/22.
//

import Foundation
import AlphaWalletAddress

public enum CollectionKey: Hashable {
    case address(AlphaWallet.Address)
    case slug(String)
}