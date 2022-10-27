//
// Created by James Sangalli on 14/7/18.
// Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import PromiseKit

public class IsErc1155Contract {
    private let server: RPCServer
    private lazy var resolver = IsInterfaceSupported165(forServer: server)

    private struct ERC165Hash {
        //https://eips.ethereum.org/EIPS/eip-1155
        static let official = "0xd9b67a26"
    }
    public init(forServer server: RPCServer) {
        self.server = server
    }

    public func getIsErc1155Contract(for contract: AlphaWallet.Address) -> Promise<Bool> {
        return resolver.getInterfaceSupported165(hash: ERC165Hash.official, contract: contract)
    }
}
