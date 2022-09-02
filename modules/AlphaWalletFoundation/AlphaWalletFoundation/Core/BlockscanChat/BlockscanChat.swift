// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import SwiftyJSON
import PromiseKit

public class BlockscanChat {
    enum E: Error {
        case invalidJson
    }

    let address: AlphaWallet.Address
    var lastKnownCount: Int?

    public init(address: AlphaWallet.Address) {
        self.address = address
    }

    public func fetchUnreadCount() -> Promise<Int> {
        infoLog("[BlockscanChat] Fetching unread count for \(address.eip55String)…")
        let url = Constants.BlockscanChat.unreadCountEndpoint.appendingPathComponent(address.eip55String)
        return firstly {
            Alamofire.request(url, headers: ["PROXY_KEY": Constants.Credentials.blockscanChatProxyKey]).validate().responseJSON(options: [])
        }.map { [weak self] rawJson, _ in
            guard let rawJson = rawJson as? [String: Any] else { throw E.invalidJson }
            let json = JSON(rawJson)
            let count = json["result"].intValue
            if let strongSelf = self {
                strongSelf.lastKnownCount = count
                infoLog("[BlockscanChat] Fetched unread count for \(strongSelf.address.eip55String) count: \(count)")
            } else {
                //no-op
            }
            return count
        }
    }
}
