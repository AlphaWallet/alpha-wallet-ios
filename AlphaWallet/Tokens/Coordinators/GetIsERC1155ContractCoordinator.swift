//
// Created by James Sangalli on 14/7/18.
// Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import PromiseKit
import Result
import web3swift

class GetIsERC1155ContractCoordinator {
    private let server: RPCServer

    private struct ERC165Hash {
        //https://eips.ethereum.org/EIPS/eip-1155
        static let official = "0xd9b67a26"
    }
    init(forServer server: RPCServer) {
        self.server = server
    }

    func getIsERC1155Contract(for contract: AlphaWallet.Address) -> Promise<Bool> {
        return GetInterfaceSupported165Coordinator(forServer: server)
            .getInterfaceSupported165(hash: ERC165Hash.official, contract: contract)
    } 
}
