// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt

struct Activity {
    //We use the internal id to track which activity to replace/update
    let id: Int
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

    var viewHtml: (html: String, hash: Int) {
        let hash = "\(view.style)\(view.html)".hashForCachingHeight
        //TODO rename "tokenId"
        return (html: wrapWithHtmlViewport(html: view.html, style: view.style, forTokenId: .init(id)), hash: hash)
    }

    var itemViewHtml: (html: String, hash: Int) {
        let hash = "\(itemView.style)\(itemView.html)".hashForCachingHeight
        //TODO rename "tokenId"
        return (html: wrapWithHtmlViewport(html: itemView.html, style: itemView.style, forTokenId: .init(id)), hash: hash)
    }
}

//TODO fix for activities: move or remove
enum ActivityOrTransaction {
    case activity(Activity)
    case transaction(Transaction)

    var date: Date {
        switch self {
        case .activity(let activity):
            return activity.date
        case .transaction(let transaction):
            return transaction.date
        }
    }
}

//TODO fix for activities: remove the need for this. Which includes support base TokenScript files
extension Constants {
    static let erc20ContractsSupportingActivities: [(address: AlphaWallet.Address, server: RPCServer, tokenScript: String)] = [
        //TODO fix for activities: remove. But for now, list all the bundled files and their contract here. Remember to remove R.file.erc20TokenScriptTsml()
        //(address: AlphaWallet.Address(string: "0x7f1511708E51A3088e4e8505F16523300668476E")!, server: .rinkeby, tokenScript: (try! String(contentsOf: R.file.erc20TokenScriptTsml()!))),
        (address: AlphaWallet.Address(string: "0x6b175474e89094c44da98b954eedeac495271d0f")!, server: .main, tokenScript: (try! String(contentsOf: R.file.daiTsml()!))),
        (address: AlphaWallet.Address(uncheckedAgainstNullAddress: "0x0000000000000000000000000000000000000000")!, server: .main, tokenScript: (try! String(contentsOf: R.file.ethTsml()!))),
        (address: AlphaWallet.Address(uncheckedAgainstNullAddress: "0x3a3a65aab0dd2a17e3f1947ba16138cd37d08c04")!, server: .main, tokenScript: (try! String(contentsOf: R.file.aETHTsml()!))),
    ]
}
