//
//  LocalNotificationService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 31.08.2022.
//

import Foundation
import UserNotifications
import AlphaWalletFoundation
import AlphaWalletNotifications

class DefaultLocalNotificationDeliveryService: LocalNotificationDeliveryService {
    private let notificationCenter: UNUserNotificationCenter

    init(notificationCenter: UNUserNotificationCenter) {
        self.notificationCenter = notificationCenter
    }

    func schedule(notification: LocalNotification) async throws {
        let request: UNNotificationRequest
        
        switch notification {
        case .receiveEther(let transaction, let amount, let wallet, let server):
            request = buildUserEtherReceivedNotification(
                id: notification.id,
                amount: amount,
                transaction: transaction,
                wallet: wallet,
                server: server)
        case .receiveToken(let transaction, let amount, let tokenType, let symbol, let wallet, let server):
            request = buildUserTokenReceivedNotification(
                id: notification.id,
                amount: amount,
                symbol: symbol,
                transaction: transaction,
                wallet: wallet,
                server: server,
                tokenType: tokenType)
        }

        try await notificationCenter.add(request)
    }

    private func buildUserTokenReceivedNotification(id: String,
                                                    amount: Decimal,
                                                    symbol: String,
                                                    transaction: String,
                                                    wallet: AlphaWallet.Address,
                                                    server: RPCServer,
                                                    tokenType: TokenType) -> UNNotificationRequest {

        let content = UNMutableNotificationContent()
        let amount = NumberFormatter.shortCrypto.string(decimal: amount) ?? "-"
        content.body = R.string.localizable.transactionsReceivedEther(amount, symbol)
        content.userInfo = [
            "transaction": transaction,
            "chainId": server.chainID,
            "amount": amount.doubleValue,
            "tokenType": tokenType.rawValue,
            "wallet": wallet.eip55String
        ]
        content.sound = .default

        return UNNotificationRequest(identifier: id, content: content, trigger: nil)
    }

    private func buildUserEtherReceivedNotification(id: String,
                                                    amount: Decimal,
                                                    transaction: String,
                                                    wallet: AlphaWallet.Address,
                                                    server: RPCServer) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        let amount = NumberFormatter.shortCrypto.string(decimal: amount) ?? "-"
        
        content.sound = .default
        content.userInfo = [
            "transaction": transaction,
            "chainId": server.chainID,
            "amount": amount.doubleValue,
            "wallet": wallet.eip55String
        ]

        switch server.serverWithEnhancedSupport {
        case .main, .xDai:
            content.body = R.string.localizable.transactionsReceivedEther(amount, server.symbol)
        case .polygon, .binance_smart_chain, .heco, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, .rinkeby, nil:
            content.body = R.string.localizable.transactionsReceivedEther("\(amount) (\(server.name))", server.symbol)
        }

        return UNNotificationRequest(identifier: id, content: content, trigger: nil)
    }
}
