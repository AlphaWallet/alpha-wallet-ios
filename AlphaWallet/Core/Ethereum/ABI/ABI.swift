//
//  ABI.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2021.
//

import Foundation

extension AlphaWallet {
    enum Ethereum {
        enum ABI {}
    }
}
extension AlphaWallet.Ethereum.ABI {
    static let ERC20: Data = {
        let url = R.file.erc20Json()!
        return try! Data(contentsOf: url)
    }()

    static let erc1155: Data = {
        let url = R.file.erc1155Json()!
        return try! Data(contentsOf: url)
    }()

    static let erc1155String: String = {
        String(data: erc1155, encoding: .utf8)!
    }()
}