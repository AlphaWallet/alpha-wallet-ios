// Copyright © 2019 Stormbird PTE. LTD.

import Foundation

//Wrapper for a few values that we keep using together
struct XmlContext {
    let namespacePrefix: String
    let namespaces: [String: String]
    let lang: String
}