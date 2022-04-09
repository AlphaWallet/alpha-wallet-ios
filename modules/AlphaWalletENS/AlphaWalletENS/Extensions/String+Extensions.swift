//
//  String+Extensions.swift
//  AlphaWalletENS
//
//  Created by Hwee-Boon Yar on Apr/8/22.

import Foundation

extension String {
    //https://github.com/ethereum/EIPs/blob/master/EIPS/eip-137.md
    public var nameHash: String {
        var node = [UInt8].init(repeating: 0x0, count: 32)
        if !self.isEmpty {
            node = self.split(separator: ".")
                    .map { Array($0.utf8).sha3(.keccak256) }
                    .reversed()
                    .reduce(node) { return ($0 + $1).sha3(.keccak256) }
        }
        return "0x" + node.toHexString()
    }
}