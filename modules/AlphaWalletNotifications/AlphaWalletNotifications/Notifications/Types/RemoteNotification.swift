//
//  RemoteNotification.swift
//  AlphaWalletNotifications
//
//  Created by Vladyslav Shepitko on 24.04.2023.
//

import Foundation
import SwiftyJSON
import AlphaWalletFoundation

public enum RemoteNotification {
    case event(Erc20TransferNotification)

    init?(json: JSON) {
        if let event = Erc20TransferNotification(json: json) {
            self = .event(event)
        }
        return nil
    }

    var walletData: (wallet: AlphaWallet.Address, rpcServer: RPCServer)? {
        switch self {
        case .event(let data):
            return (data.title.wallet, data.title.server)
        }
    }
}
