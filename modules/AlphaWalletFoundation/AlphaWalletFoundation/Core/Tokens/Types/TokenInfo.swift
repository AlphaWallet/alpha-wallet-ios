//
//  TokenInfo.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.05.2022.
//

import Foundation

public struct TokenInfo: Hashable {
    public let uid: String
    public let coinGeckoId: String?
    public let imageUrl: String?
}

extension TokenInfo {
    init(tokenInfoObject: TokenInfoObject) {
        self.uid = tokenInfoObject.uid
        self.coinGeckoId = tokenInfoObject.coinGeckoId
        self.imageUrl = tokenInfoObject.imageUrl
    }

    public init(uid: String) {
        self.uid = uid
        self.coinGeckoId = nil
        self.imageUrl = nil
    }
}
