import Foundation

extension AlphaWallet.Ethereum.ABI {
    public static let erc1155String: String = {
        String(data: erc1155, encoding: .utf8)!
    }()

    public static let erc1155: Data = {
            """
    [
      {
        "name" : "TransferSingle",
        "inputs" : [
          {
            "type" : "address",
            "indexed" : true,
            "name" : "_operator"
          },
          {
            "type" : "address",
            "indexed" : true,
            "name" : "_from"
          },
          {
            "type" : "address",
            "indexed" : true,
            "name" : "_to"
          },
          {
            "type" : "uint256",
            "name" : "_id",
            "indexed" : false
          },
          {
            "type" : "uint256",
            "name" : "_value",
            "indexed" : false
          }
        ],
        "type" : "event",
        "anonymous" : false
      },

      {
        "name" : "TransferBatch",
        "inputs" : [
          {
            "type" : "address",
            "indexed" : true,
            "name" : "_operator"
          },
          {
            "type" : "address",
            "indexed" : true,
            "name" : "_from"
          },
          {
            "type" : "address",
            "indexed" : true,
            "name" : "_to"
          },
          {
            "type" : "uint256[]",
            "name" : "_ids",
            "indexed" : false
          },
          {
            "type" : "uint256[]",
            "name" : "_values",
            "indexed" : false
          }
        ],
        "type" : "event",
        "anonymous" : false
      },

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
    """.data(using: .utf8)!
    }()
}
