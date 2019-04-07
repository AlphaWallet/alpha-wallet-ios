// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import RealmSwift

class HiddenContract: Object {
    @objc dynamic var primaryKey: String = ""
    @objc dynamic var chainId: Int = 0
    @objc dynamic var contract: String = ""

    convenience init(contract: String, server: RPCServer) {
        self.init()
        self.contract = contract
        self.chainId = server.chainID
        self.primaryKey = "\(contract)-\(server.chainID)"
    }

    override static func primaryKey() -> String? {
        return "primaryKey"
    }
}
