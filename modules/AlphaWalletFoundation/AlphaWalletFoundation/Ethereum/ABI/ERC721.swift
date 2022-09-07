import Foundation

extension AlphaWallet.Ethereum.ABI {
    public static let erc721: Data = {
        """
        [
        {
        "constant":false,
        "inputs":[
         {
            "name":"spender",
            "type":"address"
         },
         {
            "name":"approved",
            "type":"bool"
         }
        ],
        "name":"setApprovalForAll",
        "outputs":[
         {
            "name":"success",
            "type":"bool"
         }
        ],
        "payable":false,
        "stateMutability":"nonpayable",
        "type":"function"
        }
        ]
        """.data(using: .utf8)!
        }()

}
