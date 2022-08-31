// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

public struct TokenScriptSelection {
    public let id: String
    public let filter: String
    public let names: (singular: String, plural: String?)
    public let denial: String?
}

