// Copyright © 2018 Stormbird PTE. LTD. import Foundation

import Foundation

struct Web3Error: Error {
    var localizedDescription: String
    init(description: String) {
        localizedDescription = description
    }
}
