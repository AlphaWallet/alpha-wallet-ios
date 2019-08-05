// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import BigInt

typealias TokenId = BigUInt
typealias AttributeId = String

enum TokenScript {
}

extension TokenScript {
    static let repoServer = "https://repo.tokenscript.org/\(supportedTokenScriptNamespaceVersion)"
    static let repoClientName = "AlphaWallet"
    static let repoPlatformName = "iOS"
    static let tokenScriptNamespacePrefix = "http://tokenscript.org/"
    static let oldNoLongerSupportedTokenScriptNamespaceVersions = ["2019/04", "2019/05"].map { "\(tokenScriptNamespacePrefix)\($0)/tokenscript" }
    static let supportedTokenScriptNamespaceVersion = "2019/10"
    static let supportedTokenScriptNamespace = "\(tokenScriptNamespacePrefix)\(supportedTokenScriptNamespaceVersion)/tokenscript"
    static let indicesFileName = "indices"
}
