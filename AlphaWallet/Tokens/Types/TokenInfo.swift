//
//  TokenInfo.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.05.2022.
//

import Foundation

struct TokenInfo: Hashable {
    let uid: String
    let coinGeckoId: String?
    let imageUrl: String?
}

extension TokenInfo {
    init(tokenInfoObject: TokenInfoObject) {
        self.uid = tokenInfoObject.uid
        self.coinGeckoId = tokenInfoObject.coinGeckoId
        self.imageUrl = tokenInfoObject.imageUrl
    }

    init(uid: String) {
        self.uid = uid
        self.coinGeckoId = nil
        self.imageUrl = nil
    }
}
