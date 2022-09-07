//
//  Klaytn.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.03.2022.
//

import Foundation
import Alamofire
import PromiseKit
import SwiftyJSON
import BigInt

public enum Covalent {}

extension Covalent {

    public enum DecodyingError: Error {
        case fieldMismatch
        case paginationNotFound
    }

    struct Pagination {
        let hasMore: Bool
        let pageNumber: Int
        let pageSize: Int
        let totalCount: Int

        init(json: JSON) throws {
            guard
                let hasMore = json["has_more"].bool,
                let pageNumber = json["page_number"].int,
                let pageSize = json["page_size"].int,
                let totalCount = json["page_size"].int else {
                throw DecodyingError.fieldMismatch
            }

            self.hasMore = hasMore
            self.pageNumber = pageNumber
            self.pageSize = pageSize
            self.totalCount = totalCount
        }
    }

    struct DecodedLogEvent: Equatable {
        var name: String
        var signature: String
        var params: [Param]

            struct Param: Equatable {
                var name: String = ""
                var type: String = ""
                var indexed: Bool = false
                var decoded: Bool = false
                var value: String?

                init(name: String, type: String, indexed: Bool, decoded: Bool, value: String?) {
                    self.name = name
                    self.type = type
                    self.indexed = indexed
                    self.decoded = decoded
                    self.value = value
                }

                init() {
                    self.name = ""
                    self.type = ""
                    self.indexed = false
                    self.decoded = false
                    self.value = nil
                }

                init(json: JSON) throws {
                    guard
                        let name = json["name"].string,
                        let type = json["type"].string,
                        let indexed = json["indexed"].bool,
                        let decoded = json["decoded"].bool else {
                        throw DecodyingError.fieldMismatch
                    }

                    self.name = name
                    self.type = type
                    self.indexed = indexed
                    self.decoded = decoded
                    self.value = json["value"].string
                }
            }

        init(json: JSON) throws {
            guard
                let name = json["name"].string,
                let signature = json["signature"].string else {
                throw DecodyingError.fieldMismatch
            }

            self.name = name
            self.signature = signature
            self.params = json["params"].arrayValue.compactMap { try? Param(json: $0) }
        }
    }

    struct LogEvent {
        let blockSignedAt: String
        let blockHeight: Int
        let txOffset: Int
        let logOffset: Int
        let txHash: String
        let rawLogTopics: [String]
        let senderContractDecimals: Int
        let senderName: String?
        let senderContractTickerSymbol: String
        let senderAddress: String
        let senderAddressLabel: String?
        let senderLogourl: String
        let rawLogData: String?
        let decoded: DecodedLogEvent?

        init(json: JSON) throws {
            guard
                let blockSignedAt = json["block_signed_at"].string,
                let blockHeight = json["block_height"].int,
                let txOffset = json["tx_offset"].int,
                let logOffset = json["log_offset"].int,
                let txHash = json["tx_hash"].string else {
                throw DecodyingError.fieldMismatch
            }

            self.blockSignedAt = blockSignedAt
            self.blockHeight = blockHeight
            self.txOffset = txOffset
            self.txHash = txHash
            self.logOffset = logOffset
            self.senderContractDecimals = json["sender_contract_decimals"].intValue
            self.senderContractTickerSymbol = json["sender_contract_ticker_symbol"].stringValue
            self.senderName = json["sender_name"].string
            self.senderAddressLabel = json["sender_address_label"].string
            self.senderAddress = json["sender_address"].stringValue
            self.senderLogourl = json["sender_logo_url"].stringValue
            self.rawLogData = json["sender_address_label"].string
            self.decoded = try? DecodedLogEvent(json: json["decoded"])
            self.rawLogTopics = json["raw_log_topics"].arrayValue.compactMap { $0.string }
        }
        
        var params: [String: DecodedLogEvent.Param] {
            var params: [String: DecodedLogEvent.Param] = [:]

            guard let decoded = decoded else { return params }

            for index in decoded.params.indices {
                let rawLogValue = (index + 1) < rawLogTopics.count ? rawLogTopics[index + 1] : ""
                let lp: DecodedLogEvent.Param = decoded.params[index]
                var param = DecodedLogEvent.Param()
                param.name = lp.name
                param.type = lp.type

                let rawValue: String = (lp.value != nil && lp.value!.nonEmpty) ? lp.value! : rawLogValue

                if lp.type.starts(with: "uint") || lp.type.starts(with: "int") {
                    //`tokenId`s in Covalent don't start with 0x, but `value`s does
                    if rawValue.starts(with: "0x") {
                        param.value = BigInt((rawValue).drop0x, radix: 16)?.description
                    } else {
                        param.value = BigInt(rawValue)?.description
                    }
                } else {
                    param.value = rawValue
                }

                params[param.name] = param
            }

            return params
        }
    }

    struct Transaction {
        let blockHeight: Int
        let txHash: String
        let successful: Bool
        let from: String
        let to: String
        let value: String
        let blockSignedAt: String
        let gasOffered: Double?
        let gasSpent: Double?
        let gasPrice: Double?
        let gasQuote: Double?
        let gasQuoteRate: Double?
        let logEvents: [LogEvent]

        init(json: JSON) throws {
            guard
                let blockSignedAt = json["block_signed_at"].string,
                let blockHeight = json["block_height"].int,
                let txHash = json["tx_hash"].string,
                let successful = json["successful"].bool,
                let from = json["from_address"].string else {
                throw DecodyingError.fieldMismatch
            }

            self.blockSignedAt = blockSignedAt
            self.blockHeight = blockHeight
            self.txHash = txHash
            self.successful = successful
            self.from = from
            self.value = json["value"].stringValue
            self.gasOffered = json["gas_offered"].double
            self.gasSpent = json["gas_spent"].double
            self.gasPrice = json["gas_price"].double
            self.gasQuote = json["gas_quote"].double
            self.gasQuoteRate = json["gas_quote_rate"].double
            self.to = json["to_address"].stringValue
            self.logEvents = json["log_events"].arrayValue.compactMap { try? LogEvent(json: $0) }
        }
    }

    struct TransactionsData {
        let address: String
        let quoteCurrency: String
        let chainId: Int
        let transactions: [Transaction]
        let pagination: Pagination

        init(json: JSON) throws {
            guard
                let address = json["address"].string,
                let chainId = json["chain_id"].int,
                let quoteCurrency = json["quote_currency"].string,
                let items = json["items"].array else {
                throw DecodyingError.fieldMismatch
            }

            guard let pagination = try? Pagination(json: json["pagination"]) else {
                throw DecodyingError.paginationNotFound
            }

            self.address = address
            self.chainId = chainId
            self.quoteCurrency = quoteCurrency
            self.transactions = items.compactMap { try? Transaction(json: $0) }
            self.pagination = pagination
        }
    }

    struct TransactionsResponse {
        let error: Bool
        let errorMessage: String?
        let errorCode: String?
        let data: TransactionsData

        init(json: JSON) throws {
            error = json.boolValue
            errorMessage = json.string
            errorCode = json.string
            data = try TransactionsData(json: json["data"])
        }
    }

    struct BalancesResponse {
        let chainId: Int
        let address: AlphaWallet.Address
        let quoteCurrency: String
        let items: [Token]

        init(json: JSON) throws {
            guard
                let address = AlphaWallet.Address(string: json["address"].stringValue),
                let chainId = json["chain_id"].int,
                let quoteCurrency = json["quote_currency"].string,
                let items = json["items"].array else {
                throw DecodyingError.fieldMismatch
            }

            self.chainId = chainId
            self.address = address
            self.quoteCurrency = quoteCurrency
            self.items = items.compactMap { try? Token(json: $0) }
        }

        struct NFTAsset {
            let tokenId: String
            let balance: String
            let tokenUrl: String?
            let type: Token.TokenType
            let originalOwner: AlphaWallet.Address
            let owner: AlphaWallet.Address

            init(json: JSON) throws {
                guard
                    let originalOwner = AlphaWallet.Address(string: json["original_owner"].stringValue),
                    let owner = AlphaWallet.Address(string: json["owner_address"].stringValue),
                    let tokenId = json["token_id"].string,
                    let balance = json["token_balance"].string else {
                    throw DecodyingError.fieldMismatch
                }

                self.originalOwner = originalOwner
                self.owner = owner
                self.tokenId = tokenId
                self.tokenUrl = json["token_url"].string
                self.balance = balance
                self.type = try Token.TokenType(json: json["supports_erc"])
            }
        }

        struct Token {
            enum TokenType: String {
                case nativeCrypto
                case erc20
                case erc721
                case erc1155

                init(json: JSON) throws {
                    let types = json.arrayValue.compactMap { $0.string.flatMap { TokenType(rawValue: $0) } }
                    if types.isEmpty {
                        self = .nativeCrypto
                    } else if types.contains(.erc20) && types.contains(.erc721) {
                        self = .erc1155
                    } else if types.contains(.erc20) && types.count == 1 {
                        self = .erc1155
                    } else {
                        throw DecodyingError.fieldMismatch
                    }
                }
            }

            let decimals: Int
            let name: String
            let symbol: String
            let address: AlphaWallet.Address
            let type: TokenType
            let logoUrl: String
            let balance: String
            let nftBalances: [NFTAsset]

            init(json: JSON) throws {
                guard
                    let address = AlphaWallet.Address(string: json["contract_address"].stringValue),
                    let decimals = json["contract_decimals"].int,
                    let name = json["contract_name"].string,
                    let symbol = json["contract_ticker_symbol"].string else {
                    throw DecodyingError.fieldMismatch
                }

                self.decimals = decimals
                self.name = name
                self.symbol = symbol
                self.address = address
                self.type = try TokenType(json: json["supports_erc"])
                self.logoUrl = json["logo_url"].stringValue
                self.balance = json["balance"].stringValue
                self.nftBalances = json["nft_data"].arrayValue.compactMap { try? NFTAsset(json: $0) }
            } 
        }
    }
}
