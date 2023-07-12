// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress

extension AlphaWallet.Ethereum.ABI {
    public static let erc721Metadata: String = """
                                                   [
                                                   {
                                                       "constant" : true,
                                                           "inputs" : [
                                                           {
                                                               "name" : "",
                                                               "type" : "uint256"
                                                           }
                                                           ],
                                                           "name" : "tokenURI",
                                                           "outputs" : [
                                                           {
                                                               "name" : "",
                                                               "type" : "string"
                                                           }
                                                           ],
                                                           "type" : "function"
                                                   },
                                                   {
                                                       "constant" : true,
                                                       "inputs" : [
                                                       {
                                                           "name" : "",
                                                           "type" : "uint256"
                                                       }
                                                       ],
                                                       "name" : "uri",
                                                       "outputs" : [
                                                       {
                                                           "name" : "",
                                                           "type" : "string"
                                                       }
                                                       ],
                                                       "type" : "function"
                                                   }
                                               ]
        """
}