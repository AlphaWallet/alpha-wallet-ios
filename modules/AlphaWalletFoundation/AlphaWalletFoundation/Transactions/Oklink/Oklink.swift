//
//  Oklink.swift
//  Alamofire
//
//  Created by Vladyslav Shepitko on 07.03.2023.
//

import Foundation
import SwiftyJSON
import BigInt

public enum Oklink {}

protocol JsonInitializable {
    init?(json: JSON)
}

extension Oklink.Transaction: JsonInitializable { }

extension Oklink {
    
    struct TransactionListResponse<T: JsonInitializable> {
        let code: Int
        let message: String
        let data: [TransactionData<T>]

        init?(json: JSON) {
            guard let code = json["code"].string.flatMap({ Int($0) }) else { return nil }

            self.code = code
            self.message = json["message"].stringValue
            self.data = json["data"].arrayValue.compactMap { TransactionData(json: $0) }
        }
    }

    struct TransactionData<T: JsonInitializable> {
        let page: Int
        let limit: Int
        let totalPage: Int
        let chainFullName: String
        let chainShortName: String
        let transactionList: [T]

        init?(json: JSON) {
            guard
                let page = json["page"].string.flatMap({ Int($0) }),
                let limit = json["limit"].string.flatMap({ Int($0) }),
                let totalPage = json["totalPage"].string.flatMap({ Int($0) })
            else { return nil }

            self.page = page
            self.limit = limit
            self.totalPage = totalPage
            self.chainFullName = json["chainFullName"].stringValue
            self.chainShortName = json["chainShortName"].stringValue
            self.transactionList = json["transactionLists"].arrayValue.compactMap { T(json: $0) }
        }
    }

    enum ProtocolType: String {
        case transaction
        case `internal`
        case erc721 = "token_721"
        case erc1155 = "token_1155"
        case erc20 = "token_20"
    }

    enum TransactionState: String {
        case success
        case fail
        case pending
    }

    enum TransactionType: Int {
        case legacy
        case EIP2930
        case EIP1559
    }

    struct Transaction {
        let txFee: Double
        let txId: String
        let transactionSymbol: String
        let tokenContractAddress: String
        let height: Int
        let from: String
        let methodId: String
        let state: TransactionState
        let tokenId: String
        let to: String
        let blockHash: String
        let transactionTime: TimeInterval
        let amount: Double
        let transactionType: TransactionType

        init?(json: JSON) {
            guard
                let txid = json["txId"].string,
                let height = json["height"].string.flatMap({ Int($0) }),
                let state = json["state"].string.flatMap({ TransactionState(rawValue: $0) }),
                let amount = json["amount"].string.flatMap({ Double($0) }),
                let transactionTime = json["transactionTime"].string.flatMap({ TimeInterval($0) }) else { return nil }

            self.txId = txid
            self.blockHash = json["blockHash"].stringValue
            self.height = height
            self.transactionTime = transactionTime
            self.from = json["from"].stringValue
            self.to = json["to"].stringValue
            self.amount = amount
            self.transactionSymbol = json["transactionSymbol"].stringValue
            self.txFee = json["txFee"].string.flatMap { Double($0) } ?? 0
            self.methodId = json["methodId"].stringValue
            self.transactionType = json["transactionType"].string.flatMap({ Int($0) }).flatMap({ TransactionType(rawValue: $0) }) ?? .legacy
            self.state = state
            self.tokenId = json["tokenId"].stringValue
            self.tokenContractAddress = json["tokenContractAddress"].stringValue
        }
    }
}

extension NormalTransaction {
    init(okLinkTransaction transaction: Oklink.Transaction) {
        self.hash = transaction.txId
        self.blockNumber = String(transaction.height)
        self.transactionIndex = "0"
        self.timeStamp = String(transaction.transactionTime / 1000)
        self.nonce = "0"
        self.from = transaction.from
        self.to = transaction.to
        self.value = Decimal(double: transaction.amount).roundedString(decimal: 18)
        self.gas = String(transaction.txFee)
        self.gasPrice = "0"
        self.input = "0x"
        self.contractAddress = ""
        self.gasUsed = "0"
        self.error = nil
        self.isError = transaction.state == .fail ? "1" : nil
    }
}
