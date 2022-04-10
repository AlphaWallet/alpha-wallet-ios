//
//  EthereumAddressEthereumAddress+typealias.swift
//  AlphaWalletAddress
//
//  Created by Hwee-Boon Yar on Apr/10/22.

import EthereumAddress

typealias EthereumAddress_fromEthereumAddressPod = EthereumAddress

extension EthereumAddress: CustomStringConvertible {
    public var description: String {
        address
    }
}