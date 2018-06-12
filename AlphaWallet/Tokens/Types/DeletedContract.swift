// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import RealmSwift

class DeletedContract: Object {
    @objc dynamic var contract: String = ""

    convenience init(contract: String) {
        self.init()
        self.contract = contract
    }
}
