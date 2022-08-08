// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import RealmSwift

class DeletedContract: Object {
    @objc dynamic var primaryKey: String = ""
    @objc dynamic var chainId: Int = 0
    @objc dynamic var contract: String = ""

    convenience init(contractAddress: AlphaWallet.Address, server: RPCServer) {
        self.init()
        self.contract = contractAddress.eip55String
        self.chainId = server.chainID
        self.primaryKey = DeletedContract.primaryKey(contractAddress: contractAddress, server: server)
    }

    override static func primaryKey() -> String? {
        return "primaryKey"
    }

    var server: RPCServer {
        return RPCServer(chainID: chainId)
    }
    
    var contractAddress: AlphaWallet.Address {
        return AlphaWallet.Address(uncheckedAgainstNullAddress: contract)!
    }

    static func primaryKey(contractAddress: AlphaWallet.Address, server: RPCServer) -> String {
        return "\(contractAddress)-\(server.chainID)"
    }
}
