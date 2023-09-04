// Copyright © 2023 Stormbird PTE. LTD.

import Foundation

public struct AttestationAttribute {
    public let label: String
    public let path: String

    public init(label: String, path: String) {
        self.label = label
        self.path = path
    }
}