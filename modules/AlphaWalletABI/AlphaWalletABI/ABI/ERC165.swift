// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress

extension AlphaWallet.Ethereum.ABI {
    public static let erc165: String = """
                                       [
                                          {
                                             "constant" : true,
                                             "inputs" : [
                                                {
                                                   "name" : "interfaceID",
                                                   "type" : "bytes4"
                                                }
                                             ],
                                             "name" : "supportsInterface",
                                             "outputs" : [
                                                {
                                                   "name" : "",
                                                   "type" : "bool"
                                                }
                                             ],
                                             "payable" : false,
                                             "stateMutability" : "view",
                                             "type" : "function"
                                          }
                                       ]
                                       """
}