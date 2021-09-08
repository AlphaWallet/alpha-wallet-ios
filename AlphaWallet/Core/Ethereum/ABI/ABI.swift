//
//  ABI.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2021.
//

import UIKit

extension AlphaWallet {
    enum Ethereum {
        enum ABI {}
    }
}
extension AlphaWallet.Ethereum.ABI {
    static let ERC20: Data = {
        let url = Bundle.main.url(forResource: "ERC20", withExtension: "json")!
        return try! Data(contentsOf: url)
    }()

    static let erc1155: Data = {
        let url = Bundle.main.url(forResource: "ERC1155", withExtension: "json")!
        return try! Data(contentsOf: url)
    }()

    static let erc1155String: String = {
        String(data: erc1155, encoding: .utf8)!
    }()
}