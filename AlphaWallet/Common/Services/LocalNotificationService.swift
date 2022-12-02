//
//  LocalNotificationService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 31.08.2022.
//

import Foundation
import UserNotifications
import AlphaWalletFoundation

class LocalNotificationService: ScheduledNotificationService {

    func schedule(notification: LocalNotification) {
        switch notification {
        case .receiveEther(let transaction, let amount, let server):
            notifyUserEtherReceived(for: transaction, amount: amount, server: server)
        }
    }

    private func notifyUserEtherReceived(for transactionId: String, amount: String, server: RPCServer) {
        let notificationCenter = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        //TODO support other mainnets too
        switch server.serverWithEnhancedSupport {
        case .main, .xDai:
            content.body = R.string.localizable.transactionsReceivedEther(amount, server.symbol)
        case .polygon, .binance_smart_chain, .heco, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, .rinkeby, nil:
            content.body = R.string.localizable.transactionsReceivedEther("\(amount) (\(server.name))", server.symbol)
        }

        content.sound = .default
        let identifier = Constants.etherReceivedNotificationIdentifier
        let request = UNNotificationRequest(identifier: "\(identifier):\(transactionId)", content: content, trigger: nil)

        DispatchQueue.main.async {
            notificationCenter.add(request)
        }
    }
}
