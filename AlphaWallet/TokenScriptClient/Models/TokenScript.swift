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
    static let tokenScriptSite = URL(string: "http://tokenscript.org")!
    static let oldNoLongerSupportedTokenScriptNamespaceVersions = ["2019/04", "2019/05", "2019/10", "2020/03"].map { "\(tokenScriptNamespacePrefix)\($0)/tokenscript" }
    static let supportedTokenScriptNamespaceVersion = "2020/06"
    static let supportedTokenScriptNamespace = "\(tokenScriptNamespacePrefix)\(supportedTokenScriptNamespaceVersion)/tokenscript"
    static let indicesFileName = "indices"
    static let defaultBitmask: BigUInt = BigUInt("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF", radix: 16)!
    static let baseTokenScriptFiles: [TokenType: String] = [
        .erc20: (try! String(contentsOf: R.file.erc20TokenScriptTsml()!)),
        .erc721: (try! String(contentsOf: R.file.erc721TokenScriptTsml()!)),
    ]
}
