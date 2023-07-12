// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress

extension AlphaWallet.Ethereum.ABI {
    public static let erc875: String = """
                                       [
                                          {
                                             "constant" : true,
                                             "inputs" : [],
                                             "name" : "isStormBirdContract",
                                             "outputs" : [
                                                {
                                                   "name" : "",
                                                   "type" : "bool"
                                                }
                                             ],
                                             "payable" : false,
                                             "stateMutability" : "view",
                                             "type" : "function"
                                          },
                                          {
                                             "constant" : true,
                                             "inputs" : [
                                                {
                                                   "name" : "_owner",
                                                   "type" : "address"
                                                }
                                             ],
                                             "name" : "balanceOf",
                                             "outputs" : [
                                                {
                                                   "name" : "",
                                                   "type" : "bytes32[]"
                                                }
                                             ],
                                             "payable" : false,
                                             "stateMutability" : "view",
                                             "type" : "function"
                                          }
                                       ]
        """
}