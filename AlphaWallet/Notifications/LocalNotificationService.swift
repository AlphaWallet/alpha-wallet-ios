//
//  LocalNotificationService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.03.2022.
//

import Foundation
import UserNotifications

protocol ScheduledNotificationService: AnyObject {
    func schedule(notification: LocalNotification)
}

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
        switch server {
        case .main, .xDai:
            content.body = R.string.localizable.transactionsReceivedEther(amount, server.symbol)
        case .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .klaytnCypress, .klaytnBaobabTestnet, .phi, .ioTeX, .ioTeXTestnet:
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

