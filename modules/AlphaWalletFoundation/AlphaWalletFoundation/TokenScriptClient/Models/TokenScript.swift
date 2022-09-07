// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import BigInt

public typealias TokenId = BigUInt
public typealias AttributeId = String

public enum TokenScript {
}

extension TokenScript {
    public static let repoServer = "https://repo.tokenscript.org/\(supportedTokenScriptNamespaceVersion)"
    public static let repoClientName = "AlphaWallet"
    public static let repoPlatformName = "iOS"
    public static let tokenScriptNamespacePrefix = "http://tokenscript.org/"
    public static let tokenScriptSite = URL(string: "http://tokenscript.org")!
    public static let oldNoLongerSupportedTokenScriptNamespaceVersions = ["2019/04", "2019/05", "2019/10", "2020/03"].map { "\(tokenScriptNamespacePrefix)\($0)/tokenscript" }
    public static let supportedTokenScriptNamespaceVersion = "2020/06"
    public static let supportedTokenScriptNamespace = "\(tokenScriptNamespacePrefix)\(supportedTokenScriptNamespaceVersion)/tokenscript"
    public static let indicesFileName = "indices"
    public static let defaultBitmask: BigUInt = BigUInt("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF", radix: 16)!
}
