// Copyright © 2021 Stormbird PTE. LTD.

import Combine
import Foundation

public protocol Erc721TokenIdsFetcher: AnyObject {
    func tokenIdsForErc721Token(contract: AlphaWallet.Address, forServer: RPCServer, inAccount account: AlphaWallet.Address) -> AnyPublisher<[String], Never>
}
