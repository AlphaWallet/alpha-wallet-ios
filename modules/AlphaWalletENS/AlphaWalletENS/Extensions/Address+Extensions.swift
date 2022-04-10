//
//  Address+Extensions.swift
//  AlphaWalletENS
//
//  Created by Hwee-Boon Yar on Apr/9/22.

import Foundation
import AlphaWalletAddress

extension AlphaWallet.Address {
    //https://github.com/ethereum/EIPs/blob/master/EIPS/eip-137.md
    var nameHash: String {
        "\(eip55String.drop0x).addr.reverse".lowercased().nameHash
    }
}
