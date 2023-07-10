// Copyright © 2023 Stormbird PTE. LTD.

import AlphaWalletAddress
import PromiseKit

public protocol TokenScriptStatusResolver {
    func computeTokenScriptStatus(forContract contract: AlphaWallet.Address, xmlString: String, isOfficial: Bool) -> Promise<TokenLevelTokenScriptDisplayStatus>
}
