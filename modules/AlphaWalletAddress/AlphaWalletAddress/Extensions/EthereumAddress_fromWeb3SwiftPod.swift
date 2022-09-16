//
//  EthereumAddress_fromWeb3SwiftPod.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 15.09.2022.
//

import web3swift

public typealias EthereumAddress_fromWeb3SwiftPod = web3swift.EthereumAddress
extension EthereumAddress_fromWeb3SwiftPod: CustomStringConvertible {
    public var description: String {
        return address
    }
}
