// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

struct TokenScriptFileIndices {
    struct Entity {
        let name: String
        let fileName: String
    }

    var contractsToFileNames = [String: String]()
    var contractsToEntities = [String: [Entity]]()
}
