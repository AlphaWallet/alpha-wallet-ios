// Copyright © 2022 Stormbird PTE. LTD.

import Foundation

public struct DevelopmentForcedError: Error {
    public let message: String
    
    public init(message: String) {
        self.message = message
    }
}
