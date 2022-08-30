//
//  TokenInfoObject.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.05.2022.
//

import Foundation
import RealmSwift

class TokenInfoObject: Object {
    @objc dynamic var uid: String = ""
    @objc dynamic var coinGeckoId: String?
    @objc dynamic var imageUrl: String?

    convenience init(uid: String) {
        self.init()
        self.uid = uid
    }

    override static func primaryKey() -> String? {
        return "uid"
    }

    convenience init(tokenInfo: TokenInfo) {
        self.init()
        self.uid = tokenInfo.uid
        self.coinGeckoId = tokenInfo.coinGeckoId
        self.imageUrl = tokenInfo.imageUrl
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? TokenInfoObject else { return false }
        //NOTE: to improve perfomance seems like we can use check for primary key instead of checking contracts
        return object.uid == uid
    }
}
