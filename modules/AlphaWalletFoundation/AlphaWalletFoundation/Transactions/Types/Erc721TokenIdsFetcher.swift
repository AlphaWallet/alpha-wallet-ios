// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import PromiseKit

public protocol Erc721TokenIdsFetcher: AnyObject {
    func tokenIdsForErc721Token(contract: AlphaWallet.Address, forServer: RPCServer, inAccount account: AlphaWallet.Address) -> Promise<[String]>
}
