// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import AlphaWalletTokenScript
import BigInt

public struct Activity {
    public enum NativeViewType {
        case nativeCryptoSent
        case nativeCryptoReceived
        case erc20Sent
        case erc20Received
        case erc20OwnerApproved
        case erc20ApprovalObtained
        case erc721Sent
        case erc721Received
        case erc721OwnerApproved
        case erc721ApprovalObtained
        //TODO support ERC721 setApprovalForAll()
        case none
    }

    public enum State {
        case pending
        case completed
        case failed
    }

    //We use the internal id to track which activity to replace/update
    public let id: Int
    public var rowType: ActivityRowType
    public let token: Token
    public let server: RPCServer
    public let name: String
    public let eventName: String
    public let blockNumber: Int
    public let transactionId: String
    public let transactionIndex: Int
    public let logIndex: Int
    public let date: Date
    public let values: (token: [AttributeId: AssetInternalValue], card: [AttributeId: AssetInternalValue])
    public let view: (html: String, style: String)
    public let itemView: (html: String, style: String)
    public let isBaseCard: Bool
    public let state: State

    public init() {
        self.init(id: 0, rowType: .item, token: .init(), server: .main, name: "", eventName: "", blockNumber: 0, transactionId: "", transactionIndex: 0, logIndex: 0, date: Date(), values: (token: [:], card: [:]), view: (html: "", style: ""), itemView: (html: "", style: ""), isBaseCard: false, state: .completed)
    }

    public init(id: Int, rowType: ActivityRowType, token: Token, server: RPCServer, name: String, eventName: String, blockNumber: Int, transactionId: String, transactionIndex: Int, logIndex: Int, date: Date, values: (token: [AttributeId: AssetInternalValue], card: [AttributeId: AssetInternalValue]), view: (html: String, style: String), itemView: (html: String, style: String), isBaseCard: Bool, state: State) {
        self.id = id
        self.token = token
        self.server = server
        self.name = name
        self.eventName = eventName
        self.blockNumber = blockNumber
        self.transactionId = transactionId
        self.transactionIndex = transactionIndex
        self.logIndex = logIndex
        self.date = date
        self.values = values
        self.view = view
        self.itemView = itemView
        self.isBaseCard = isBaseCard
        self.state = state
        self.rowType = rowType
    }

    public var viewHtml: String {
        return wrapWithHtmlViewport(html: view.html, style: view.style, forTokenId: .init(id))
    }

    public var itemViewHtml: String {
        return wrapWithHtmlViewport(html: itemView.html, style: itemView.style, forTokenId: .init(id))
    }

    public var nativeViewType: NativeViewType {
        switch token.type {
        case .nativeCryptocurrency:
            switch name {
            case "sent":
                return .nativeCryptoSent
            case "received":
                return .nativeCryptoReceived
            default:
                return .none
            }
        case .erc20:
            if isBaseCard {
                switch name {
                case "sent":
                    return .erc20Sent
                case "received":
                    return .erc20Received
                case "ownerApproved":
                    return .erc20OwnerApproved
                case "approvalObtained":
                    return .erc20ApprovalObtained
                default:
                    return .none
                }
            } else {
                return .none
            }
        case .erc721, .erc721ForTickets, .erc1155:
            if isBaseCard {
                switch name {
                case "sent":
                    return .erc721Sent
                case "received":
                    return .erc721Received
                case "ownerApproved":
                    return .erc721OwnerApproved
                case "approvalObtained":
                    return .erc721ApprovalObtained
                default:
                    return .none
                }
            } else {
                return .none
            }
        case .erc875:
            return .none
        }
    }

    public var isSend: Bool {
        name == "sent"
    }

    public var isReceive: Bool {
        name == "received"
    }
}
