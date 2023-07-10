// Copyright © 2019 Stormbird PTE. LTD.

import Foundation

//Wrapper for a few values that we keep using together
public struct XmlContext {
    public let namespacePrefix: String
    public let namespaces: [String: String]
    public let lang: String

    public init(namespacePrefix: String, namespaces: [String: String], lang: String) {
        self.namespacePrefix = namespacePrefix
        self.namespaces = namespaces
        self.lang = lang
    }
}
