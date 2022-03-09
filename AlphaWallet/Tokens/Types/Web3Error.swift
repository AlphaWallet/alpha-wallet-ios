// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

struct Web3Error: LocalizedError {
    private let localizedDescription: String
    init(description: String) {
        localizedDescription = description
    }

    public var errorDescription: String? {
        return localizedDescription
    }
}
