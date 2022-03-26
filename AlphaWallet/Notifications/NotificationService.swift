//
//  NotificationService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.03.2022.
//

import Foundation
import Combine
import UIKit

protocol NotificationSourceService: AnyObject {
    var receiveNotification: AnyPublisher<LocalNotification, Never> { get }

    func start(wallet: Wallet)
}

class NotificationService {
    @Published private var sources: [NotificationSourceService]
    private var cancelable = Set<AnyCancellable>()
    private let notificationService: ScheduledNotificationService = LocalNotificationService()
    private var receiveNotificationSubject: PassthroughSubject<LocalNotification, Never> = .init()
    private var walletBalanceService: WalletBalanceService
    private var pushNotificationsService = PushNotificationsService()

    var receiveNotification: AnyPublisher<LocalNotification, Never> {
        receiveNotificationSubject.eraseToAnyPublisher()
    }

    init(sources: [NotificationSourceService], walletBalanceService: WalletBalanceService) {
        self.sources = sources
        self.walletBalanceService = walletBalanceService

        $sources
            .flatMap { Publishers.MergeMany( $0.map(\.receiveNotification) ) }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.schedule(notification: notification)
            }.store(in: &cancelable)
    }

    func register(source: NotificationSourceService) {
        guard !sources.contains(where: { $0 === source }) else { return }
        sources.append(source)
    }

    func unregister(source: NotificationSourceService) {
        sources = sources.filter { $0 !== source }
    }

    func start(wallet: Wallet) {
        for each in sources {
            each.start(wallet: wallet)
        }
    }

    func registerForReceivingRemoteNotifications() {
        pushNotificationsService.registerForReceivingRemoteNotifications()
    }

    func requestToEnableNotification() {
        pushNotificationsService.requestToEnableNotification()
    }

    private func schedule(notification: LocalNotification) {
        receiveNotificationSubject.send(notification)
        notificationService.schedule(notification: notification)
    }
}
