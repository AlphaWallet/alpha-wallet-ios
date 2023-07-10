// Copyright © 2023 Stormbird PTE. LTD.

import Foundation

public struct Web3Error: LocalizedError {
    private let localizedDescription: String
    public init(description: String) {
        localizedDescription = description
    }

    public var errorDescription: String? {
        return localizedDescription
    }
}