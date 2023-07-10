// Copyright © 2023 Stormbird PTE. LTD.

import Foundation

//This must be a class and not a struct since we share it
public class TokenScriptFeatures {
    public var isActivityEnabled: Bool = true
    public var isTokenScriptSignatureStatusEnabled: Bool = false
    public var shouldLoadTokenScriptWithFailedSignatures: Bool = true

    public init() {
    }
}
