// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

public struct TokenScriptSelection {
    public let id: String
    public let filter: String
    public let names: (singular: String, plural: String?)
    public let denial: String?

    public init(id: String, filter: String, names: (singular: String, plural: String?), denial: String?) {
        self.id = id
        self.filter = filter
        self.names = names
        self.denial = denial
    }
}

