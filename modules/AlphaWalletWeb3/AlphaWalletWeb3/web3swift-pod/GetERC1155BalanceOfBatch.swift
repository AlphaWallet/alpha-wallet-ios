// Copyright © 2023 Stormbird PTE. LTD.

import Foundation

struct GetERC1155BalanceOfBatch {
    let abi = """
              [
                    {
                      "name" : "balanceOfBatch",
                      "constant": true,
                      "type" : "function",
                      "inputs" : [
                        {
                          "type" : "address[]",
                          "name" : "_owners"
                        },
                        {
                          "type" : "uint256[]",
                          "name" : "_ids"
                        },
                      ],
                      "outputs" : [
                        {
                          "type" : "uint256[]",
                          "name" : ""
                        }
                      ]
                    }
              ]
              """
}
