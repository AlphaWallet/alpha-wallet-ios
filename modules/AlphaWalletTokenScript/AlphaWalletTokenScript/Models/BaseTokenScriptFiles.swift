// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import AlphaWalletCore

public final class BaseTokenScriptFiles {
    private let _baseTokenScriptFiles: AtomicDictionary<TokenType, String> = .init()

    public init(baseTokenScriptFiles: [TokenType: String] = [:]) {
        _baseTokenScriptFiles.set(value: baseTokenScriptFiles)
    }

    public func containsBaseTokenScriptFile(for file: XMLFile) -> Bool {
        return _baseTokenScriptFiles.contains(where: { $1 == file })
    }

    public func baseTokenScriptFile(for tokenType: TokenType) -> XMLFile? {
        return _baseTokenScriptFiles[tokenType]
    }
}
