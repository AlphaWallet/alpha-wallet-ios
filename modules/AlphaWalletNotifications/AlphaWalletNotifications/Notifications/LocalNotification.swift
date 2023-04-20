//
//  LocalNotification.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.03.2022.
//

import Foundation
import AlphaWalletFoundation

public enum LocalNotification: Equatable {
    case receiveEther(transaction: String, amount: Decimal, wallet: AlphaWallet.Address, server: RPCServer)
    case receiveToken(transaction: String, amount: Decimal, tokenType: TokenType, symbol: String, wallet: AlphaWallet.Address, server: RPCServer)

    public var id: String {
        switch self {
        case .receiveEther(let transaction, _, _, let server):
            return "\(LocalNotification.notificationPrefix)-etherReceived-\(transaction)-\(server.chainID)"
        case .receiveToken(let transaction, _, _, _, _, let server):
            return "\(LocalNotification.notificationPrefix)-tokenReceived-\(transaction)-\(server.chainID)"
        }
    }
}

extension LocalNotification {
    private static let notificationPrefix = "LocalNotification"
    
    static func isLocalNotification(_ notification: UNNotification) -> Bool {
        return notification.request.identifier.lowercased().contains(notificationPrefix.lowercased())
    }

    public init?(userInfo: RemoteNotificationUserInfo) {
        if let transaction = userInfo["transaction"] as? String,
           let amount = userInfo["amount"] as? Double,
           let chainId = userInfo["chainId"] as? Int,
           let wallet = userInfo["wallet"] as? String, let address = AlphaWallet.Address(string: wallet) {

            self = .receiveEther(
                transaction: transaction,
                amount: Decimal(amount),
                wallet: address,
                server: RPCServer(chainID: chainId))

        } else if let transaction = userInfo["transaction"] as? String,
                  let amount = userInfo["amount"] as? Double,
                  let chainId = userInfo["chainId"] as? Int,
                  let tokenTypeRaw = userInfo["tokenType"] as? String, let tokenType = TokenType(rawValue: tokenTypeRaw),
                  let symbol = userInfo["symbol"] as? String,
                  let wallet = userInfo["wallet"] as? String, let address = AlphaWallet.Address(string: wallet) {

            self = .receiveToken(
                transaction: transaction,
                amount: Decimal(amount),
                tokenType: tokenType,
                symbol: symbol,
                wallet: address,
                server: RPCServer(chainID: chainId))
        } else {
            return nil
        }
    }
}
