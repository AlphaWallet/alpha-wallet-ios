//
//  TickerIdObject.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 05.09.2022.
//

import Foundation
import RealmSwift

class TickerIdObject: Object {
    @objc dynamic var id: String = ""
    @objc dynamic var symbol: String = ""
    @objc dynamic var name: String = ""
    let platforms = List<ContractAddressObject>()

    convenience init(tickerId: TickerId) {
        self.init()
        id = tickerId.id
        symbol = tickerId.symbol
        name = tickerId.name
        platforms.append(objectsIn: tickerId.platforms.map { ContractAddressObject(contract: $0.address, server: $0.server) })
    }

    override static func primaryKey() -> String? {
        return "id"
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? TickerIdObject else { return false }
        return object.id == id
    }
}
