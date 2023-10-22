//
//  NotificationHandler.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 24.04.2023.
//

import Foundation
import Combine
import SwiftyJSON
import AlphaWalletFoundation

public protocol NotificationHandler: AnyObject {
    var navigation: PushNotificationNavigatable? { get set }

    func willPresentNotification(userInfo: RemoteNotificationUserInfo) async
    func process(userInfo: RemoteNotificationUserInfo, appStartedFromPush: Bool) async -> UIBackgroundFetchResult
}

public protocol PushNotificationNavigatable: AnyObject {
    func show(transaction: Transaction)
}

public class AlphaWalletNotificationHandler: NotificationHandler {
    private let application: UIApplication
    private let notificationCenter: NotificationCenter
    private var receivedPushNotification: RemoteNotification?
    private var receivedLocalNotification: LocalNotification?
    private let walletsDependencies: WalletDependenciesProvidable
    private var cancellable = Set<AnyCancellable>()
    private let pushNotificationSubject = PassthroughSubject<RemoteNotification, Never>()
    private let keystore: Keystore

    //TODO: remove it later
    private let notificationsServer: RPCServer = .main
    public var pushNotificationPublisher: AnyPublisher<RemoteNotification, Never> {
        pushNotificationSubject.eraseToAnyPublisher()
    }

    public weak var navigation: PushNotificationNavigatable?

    public init(application: UIApplication,
                notificationCenter: NotificationCenter,
                walletsDependencies: WalletDependenciesProvidable,
                navigationHandler: ApplicationNavigationHandler,
                keystore: Keystore) {

        self.walletsDependencies = walletsDependencies
        self.application = application
        self.notificationCenter = notificationCenter
        self.keystore = keystore

        notificationCenter.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.handleReceivedNotification() }
            .store(in: &cancellable)

        navigationHandler.publisher
            .filter { $0 == .selectedWallet }
            .sink { [weak self] _ in self?.handleReceivedNotification() }
            .store(in: &cancellable)
    }

    @objc private func handleReceivedNotification() {
        if let notification = receivedLocalNotification {
            handle(localNotification: notification)

            receivedLocalNotification = nil
        }
    }

    private func handle(localNotification: LocalNotification) {
        switch localNotification {
        case .receiveEther(let transaction, _, let wallet, let server):
            guard keystore.currentWallet?.address == wallet else { return }

            guard let dep = walletsDependencies.walletDependencies(walletAddress: wallet) else { return }
            Task { @MainActor in
                guard let transaction = await dep.transactionsService.transaction(withTransactionId: transaction, forServer: server) else { return }
                navigation?.show(transaction: transaction)
            }
        case .receiveToken(let transaction, _, _, let symbol, let wallet, let server):
            guard keystore.currentWallet?.address == wallet else { return }

            guard let dep = walletsDependencies.walletDependencies(walletAddress: wallet) else { return }
            Task { @MainActor in
                guard let transaction = await dep.transactionsService.transaction(withTransactionId: transaction, forServer: server) else { return }
                navigation?.show(transaction: transaction)
            }
        }
    }

    /// Called when notificatio will be presented
    @MainActor public func willPresentNotification(userInfo: RemoteNotificationUserInfo) async {
        await handle(remoteNotification: userInfo)
    }

    @discardableResult private func handle(remoteNotification userInfo: RemoteNotificationUserInfo) async -> UIBackgroundFetchResult {
        let json = JSON(userInfo)

        //TODO: verify received json, it might be different from we expected for now
        guard let notification = RemoteNotification(json: json["aps"]["body"]), let walletData = notification.walletData else { return .noData }
        guard keystore.currentWallet?.address == walletData.wallet else { return .noData }

        if let dep = walletsDependencies.walletDependencies(walletAddress: walletData.wallet) {
            await dep.transactionsService.forceResumeOrStart(server: walletData.rpcServer)
            return .newData
        }

        return .noData
    }

    //TODO: rename appStartedFromPush with enum
    /// Called when user taps on notification when app has already launched or when its launching
    @MainActor public func process(userInfo: RemoteNotificationUserInfo, appStartedFromPush: Bool) async -> UIBackgroundFetchResult {
        let json = JSON(userInfo)

        if let notification = LocalNotification(userInfo: userInfo) {
            switch await application.applicationState {
            case .background, .inactive:
                if appStartedFromPush {
                    self.receivedLocalNotification = notification
                }
            default:
                handle(localNotification: notification)
            }
            return .newData
        } else {
            return await handle(remoteNotification: userInfo)
        }

        return .noData
    }
}

public typealias RemoteNotificationUserInfo = [AnyHashable: Any]
