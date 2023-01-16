// Copyright © 2022 Stormbird PTE. LTD.

import Foundation

public struct DevelopmentForcedError: LocalizedError {
    public let message: String
    
    public init(message: String) {
        self.message = message
    }

    public var errorDescription: String? {
        return message
    }
}
