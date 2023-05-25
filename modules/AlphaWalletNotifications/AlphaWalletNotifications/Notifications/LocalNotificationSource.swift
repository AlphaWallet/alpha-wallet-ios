//
//  LocalNotificationService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.03.2022.
//

import Foundation
import Combine
import BigInt
import AlphaWalletFoundation

public protocol LocalNotificationSource: AnyObject {
    var receiveNotification: AnyPublisher<LocalNotification, Never> { get }

    func buildNotifications(transactions: [Transaction]) -> [LocalNotification]
    func start()
    func stop()
}

public final class LocalNotificationService {
    @Published private var sources: [LocalNotificationSource]
    private var cancelable = Set<AnyCancellable>()
    private let deliveryService: LocalNotificationDeliveryService

    public init(sources: [LocalNotificationSource],
                deliveryService: LocalNotificationDeliveryService) {

        self.sources = sources
        self.deliveryService = deliveryService

        $sources
            .flatMap { Publishers.MergeMany($0.map(\.receiveNotification)) }
            .removeDuplicates()
            .sink { [deliveryService] notification in
                Task { @MainActor in
                    try? await deliveryService.schedule(notification: notification)
                }
            }.store(in: &cancelable)
    }

    public func register(source: LocalNotificationSource) {
        guard !sources.contains(where: { $0 === source }) else { return }
        sources.append(source)
    }

    public func unregister(source: LocalNotificationSource) {
        sources = sources.filter { $0 !== source }
    }

    public func start() {
        for each in sources {
            each.start()
        }
    }

    public func stop() {
        for each in sources {
            each.stop()
        }
    }
}
