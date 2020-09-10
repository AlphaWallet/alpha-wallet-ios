// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt

struct Activity {
    enum NativeViewType {
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
        case none
    }

    //We use the internal id to track which activity to replace/update
    let id: Int
    //TODO safe to have TokenObject here? Maybe a struct is better
    let tokenObject: TokenObject
    let server: RPCServer
    let name: String
    let eventName: String
    let blockNumber: Int
    let transactionId: String
    let date: Date
    let values: (token: [AttributeId: AssetInternalValue], card: [AttributeId: AssetInternalValue])
    let view: (html: String, style: String)
    let itemView: (html: String, style: String)
    let isBaseCard: Bool

    var viewHtml: (html: String, hash: Int) {
        let hash = "\(view.style)\(view.html)".hashForCachingHeight
        return (html: wrapWithHtmlViewport(html: view.html, style: view.style, forTokenId: .init(id)), hash: hash)
    }

    var itemViewHtml: (html: String, hash: Int) {
        let hash = "\(itemView.style)\(itemView.html)".hashForCachingHeight
        return (html: wrapWithHtmlViewport(html: itemView.html, style: itemView.style, forTokenId: .init(id)), hash: hash)
    }

    var nativeViewType: NativeViewType {
        switch tokenObject.type {
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
        case .erc721, .erc721ForTickets:
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
}

//TODO We can use the repo server instead and remove this after testing
extension Constants {
    static let erc20ContractsSupportingActivities: [(address: AlphaWallet.Address, server: RPCServer, tokenScript: String)] = [
        //(address: AlphaWallet.Address(string: "0x6b175474e89094c44da98b954eedeac495271d0f")!, server: .main, tokenScript: (try! String(contentsOf: R.file.daiTsml()!))),
        //(address: AlphaWallet.Address(uncheckedAgainstNullAddress: "0x0000000000000000000000000000000000000000")!, server: .main, tokenScript: (try! String(contentsOf: R.file.ethTsml()!))),
        //(address: AlphaWallet.Address(uncheckedAgainstNullAddress: "0x3a3a65aab0dd2a17e3f1947ba16138cd37d08c04")!, server: .main, tokenScript: (try! String(contentsOf: R.file.aETHTsml()!))),
    ]
}
