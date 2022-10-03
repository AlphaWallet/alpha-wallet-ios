//
//  EthereumAddress_fromWeb3.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 15.09.2022.
//

import AlphaWalletWeb3

public typealias EthereumAddress_fromWeb3 = AlphaWalletWeb3.EthereumAddress
extension EthereumAddress_fromWeb3: CustomStringConvertible {
    public var description: String {
        return address
    }
}
