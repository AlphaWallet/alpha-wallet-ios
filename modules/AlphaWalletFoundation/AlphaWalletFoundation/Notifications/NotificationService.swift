//
//  NotificationService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.03.2022.
//

import Foundation
import Combine
import BigInt

public protocol PushNotificationsService: AnyObject {
    func registerForReceivingRemoteNotifications()
    func requestToEnableNotification()
}

public protocol NotificationSourceServiceDelegate: AnyObject {
    func showCreateBackupAfterReceiveNativeCryptoCurrencyPrompt(in service: NotificationSourceService, etherReceivedUsedForBackupPrompt: BigInt)
}

public protocol NotificationSourceService: AnyObject {
    var receiveNotification: AnyPublisher<LocalNotification, Never> { get }
    var delegate: NotificationSourceServiceDelegate? { get set }
    
    func start(wallet: Wallet)
}

public final class NotificationService {
    @Published private var sources: [NotificationSourceService]
    private var cancelable = Set<AnyCancellable>()
    private let notificationService: ScheduledNotificationService
    private let receiveNotificationSubject: PassthroughSubject<LocalNotification, Never> = .init()
    private let walletBalanceService: WalletBalanceService
    private let pushNotificationsService: PushNotificationsService

    public var receiveNotification: AnyPublisher<LocalNotification, Never> {
        receiveNotificationSubject.eraseToAnyPublisher()
    }

    public init(sources: [NotificationSourceService], walletBalanceService: WalletBalanceService, notificationService: ScheduledNotificationService, pushNotificationsService: PushNotificationsService) {
        self.sources = sources
        self.notificationService = notificationService
        self.walletBalanceService = walletBalanceService
        self.pushNotificationsService = pushNotificationsService

        $sources
            .flatMap { Publishers.MergeMany($0.map(\.receiveNotification)) }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.schedule(notification: notification)
            }.store(in: &cancelable)
    }

    public func register(source: NotificationSourceService) {
        guard !sources.contains(where: { $0 === source }) else { return }
        sources.append(source)
    }

    public func unregister(source: NotificationSourceService) {
        sources = sources.filter { $0 !== source }
    }

    public func start(wallet: Wallet) {
        for each in sources {
            each.start(wallet: wallet)
        }
    }

    public func registerForReceivingRemoteNotifications() {
        pushNotificationsService.registerForReceivingRemoteNotifications()
    }

    public func requestToEnableNotification() {
        pushNotificationsService.requestToEnableNotification()
    }

    private func schedule(notification: LocalNotification) {
        receiveNotificationSubject.send(notification)
        notificationService.schedule(notification: notification)
    }
}
