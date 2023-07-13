//
//  PushNotificationsService.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 24.04.2023.
//

import Foundation
import UIKit
import UserNotifications
import AlphaWalletFoundation
import Combine
import FirebaseMessaging
import AlphaWalletCore
import AlphaWalletLogger

public protocol PushNotificationsService: AnyObject, UNUserNotificationCenterDelegate {
    func isSubscribedForNotifiation(wallet: Wallet) -> AnyPublisher<Loadable<Bool, Error>, Never>
    func subscribe(wallet: Wallet) -> AnyPublisher<Bool, Never>
    func unsubscribe(wallet: Wallet) -> AnyPublisher<Bool, Never>
    func requestToEnableNotification()
    func register(deviceToken: Result<Data, Error>)
    func handle(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) async
    func handle(remoteNotification userInfo: RemoteNotificationUserInfo) async -> UIBackgroundFetchResult
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async
}

//FIXME: Crucial, update google plist info file before push notifications testing
public class BasePushNotificationsService: NSObject, PushNotificationsService {
    private let unUserNotificationService: UNUserNotificationsService
    private let keystore: Keystore
    private let networking: PushNotificationsNetworking
    private var cancellable = Set<AnyCancellable>()
    private let notificationsServer: RPCServer = .main
    @Published private var subscriptions: [AlphaWallet.Address: SubscriptionState] = [:]

    private let notificationHandler: NotificationHandler
    private var isAuthorizationStatusAuthorized: AnyPublisher<Loadable<Bool, Error>, Never> {
        unUserNotificationService
            .$settings
            .map { $0.map { .done($0.authorizationStatus == .authorized) } }
            .eraseToAnyPublisher()
    }
    private let isSubscribedStorage: NotificationSubscribersStorage

    private struct SubscriptionState {
        var loadingState: Loadable<Void, Error>?
        var subscription: PushNotificationSubscription?
        var cancellable: Cancellable?

        var isSubscribed: Bool {
            guard let subscription = subscription else { return false }
            return subscription.trimmed.nonEmpty
        }
    }

    public init(unUserNotificationService: UNUserNotificationsService,
                keystore: Keystore,
                networking: PushNotificationsNetworking,
                notificationHandler: NotificationHandler,
                isSubscribedStorage: NotificationSubscribersStorage) {

        self.isSubscribedStorage = isSubscribedStorage
        self.notificationHandler = notificationHandler
        self.networking = networking
        self.keystore = keystore
        self.unUserNotificationService = unUserNotificationService
        super.init()

        guard Features.current.isAvailable(.areNotificationsEnabled) else { return }

        keystore.didAddWallet
            .flatMap { self.requestSilentAuthorization(wallet: $0.wallet) }
            .sink { _ in }
            .store(in: &cancellable)

        keystore.didRemoveWallet
            .flatMap { wallet in self.unsubscribe(wallet: wallet).map { _ in wallet } }
            .sink { [weak self] wallet in self?.subscriptions[wallet.address] = nil }
            .store(in: &cancellable)

        //NOTE: since we don't have api to check subscriptions, we track it manually and send send subscribe request initially if `authorizationStatus == .authorized`, only for wallets those are not disabled manually from subscribing
        let publishers = keystore.wallets
            .filter {
                guard let value = isSubscribedStorage[$0.address] else { return true }
                return value
            }.map { self.requestSilentAuthorization(wallet: $0) }

        Publishers.MergeMany(publishers)
            .sink { _ in }
            .store(in: &cancellable)
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        guard Features.current.isAvailable(.areNotificationsEnabled) else { return [] }
        infoLog("[UNUserNotificationsService] will present notification: \(notification.request.content.userInfo)")
        //NOTE: we don't display push notification popup, refresh transactions instead and display local notificiations popups
        //that only when app is alive, when its closed a push popup will be presented by system, that should be handled too, maybe in some next steps:
        //- load all latest transactions
        //- build notifications for each of transaction
        //- select first transaction and open transaction details screen for it.

        guard LocalNotification.isLocalNotification(notification) else {
            await notificationHandler.willPresentNotification(userInfo: notification.request.content.userInfo)
            return []
        }

        return [.badge, .sound, .alert]
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard Features.current.isAvailable(.areNotificationsEnabled) else { return }
        let userInfo = response.notification.request.content.userInfo
        infoLog("[UNUserNotificationsService] did receive response: \(userInfo)")
        _ = await notificationHandler.process(userInfo: userInfo, appStartedFromPush: true)
    }

    public func requestToEnableNotification() {
        guard Features.current.isAvailable(.areNotificationsEnabled) else { return }
        Task { @MainActor in
            await unUserNotificationService.requestToEnableNotification()
        }
    }

    public func isSubscribedForNotifiation(wallet: Wallet) -> AnyPublisher<Loadable<Bool, Error>, Never> {
        Publishers.CombineLatest(isAuthorizationStatusAuthorized, $subscriptions)
            .map { isAuthorized, subscriptions in
                if let state = subscriptions[wallet.address], let loadingState = state.loadingState {
                    return loadingState.zip(isAuthorized).map {
                        .done($0.1 && state.isSubscribed)
                    }
                } else {
                    return isAuthorized.map { _ in return .done(false) }
                }
            }.eraseToAnyPublisher()
    }

    public func subscribe(wallet: Wallet) -> AnyPublisher<Bool, Never> {
        getOrCreateSubscriptionState(wallet: wallet)

        subscriptions[wallet.address]?.loadingState = .loading
        let subscription = "\(wallet.address)-\(notificationsServer.chainID)"

        let subscribeSubject = PassthroughSubject<Bool, Never>()
        let cancellable = buildSubscribe(wallet: wallet, subscription: subscription)
            .handleEvents(receiveOutput: { [weak self] hasSubscribed in
                self?.isSubscribedStorage[wallet.address] = hasSubscribed

                self?.subscriptions[wallet.address]?.subscription = hasSubscribed ? subscription : nil
            }, receiveCompletion: { [weak self] _ in
                self?.subscriptions[wallet.address]?.loadingState = .done(())
                self?.subscriptions[wallet.address]?.cancellable = nil
            }, receiveCancel: { [weak self] in
                self?.subscriptions[wallet.address]?.loadingState = .done(())
            })
            .multicast(subject: subscribeSubject)
            .connect()

        subscriptions[wallet.address]?.cancellable?.cancel()
        subscriptions[wallet.address]?.cancellable = cancellable

        return subscribeSubject.handleEvents(receiveCancel: { cancellable.cancel() })
            .eraseToAnyPublisher()
    }

    private func buildSubscribe(wallet: Wallet, subscription: String) -> AnyPublisher<Bool, Never> {
        Future(operation: unUserNotificationService.requestAuthorization)
            .replaceError(with: false)
            .flatMap { [networking, notificationsServer, unUserNotificationService] granted -> AnyPublisher<Bool, Never> in
                if granted {
                    return networking.subscribe(walletAddress: wallet.address, server: notificationsServer)
                        .flatMap { hasSubscribed -> AnyPublisher<Bool, Never> in
                            if hasSubscribed {
                                return unUserNotificationService.subscribe(to: subscription)
                            } else {
                                return .just(hasSubscribed)
                            }
                        }.eraseToAnyPublisher()
                } else {
                    return .just(false)
                }
            }.receive(on: RunLoop.main)
            .timeout(.seconds(60), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }

    private func requestSilentAuthorization(wallet: Wallet) -> AnyPublisher<Bool, Never> {
        getOrCreateSubscriptionState(wallet: wallet)

        subscriptions[wallet.address]?.loadingState = .loading

        let subscription = "\(wallet.address)-\(notificationsServer.chainID)"
        let subscribeSubject = PassthroughSubject<Bool, Never>()
        let cancellable = buildSilentAuthorization(wallet: wallet, subscription: subscription)
            .handleEvents(receiveOutput: { [weak self] hasSubscribed in
                self?.isSubscribedStorage[wallet.address] = hasSubscribed
                self?.subscriptions[wallet.address]?.subscription = hasSubscribed ? subscription : nil
            }, receiveCompletion: { [weak self] _ in
                self?.subscriptions[wallet.address]?.loadingState = .done(())
                self?.subscriptions[wallet.address]?.cancellable = nil
            }, receiveCancel: { [weak self] in
                self?.subscriptions[wallet.address]?.loadingState = .done(())
            })
            .multicast(subject: subscribeSubject)
            .connect()

        subscriptions[wallet.address]?.cancellable?.cancel()
        subscriptions[wallet.address]?.cancellable = cancellable

        return subscribeSubject.handleEvents(receiveCancel: { cancellable.cancel() })
            .eraseToAnyPublisher()
    }

    @discardableResult private func getOrCreateSubscriptionState(wallet: Wallet) -> SubscriptionState {
        if let state = subscriptions[wallet.address] {
            return state
        } else {
            let state = SubscriptionState(loadingState: nil)
            subscriptions[wallet.address] = state

            return state
        }
    }

    private func buildSilentAuthorization(wallet: Wallet, subscription: String) -> AnyPublisher<Bool, Never> {
        unUserNotificationService.$settings
            .compactMap { $0.value }
            .filter { $0.authorizationStatus == .authorized }
            .first()
            .flatMap { [networking, notificationsServer, unUserNotificationService] _ -> AnyPublisher<Bool, Never> in
                return networking.subscribe(walletAddress: wallet.address, server: notificationsServer)
                    .flatMap { hasSubscribed -> AnyPublisher<Bool, Never> in
                        if hasSubscribed {
                            return unUserNotificationService.subscribe(to: subscription)
                        } else {
                            return .just(hasSubscribed)
                        }
                    }.eraseToAnyPublisher()
            }.receive(on: RunLoop.main)
            .timeout(.seconds(60), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }

    private func buildUnsubscribe(wallet: Wallet) -> AnyPublisher<Bool, Never> {
        Future(operation: unUserNotificationService.unregisterRemoteNotifications)
            .replaceError(with: false)
            .flatMap { [networking, notificationsServer, unUserNotificationService] _ -> AnyPublisher<Bool, Never> in
                return networking.unsubscribe(walletAddress: wallet.address, server: notificationsServer)
                    .flatMap { hasUnsubscribed -> AnyPublisher<Bool, Never> in
                        if hasUnsubscribed {
                            return unUserNotificationService.unsubscribe(from: "\(wallet.address)-\(notificationsServer)")
                        } else {
                            return .just(hasUnsubscribed)
                        }
                    }.eraseToAnyPublisher()
            }.receive(on: RunLoop.main)
            .timeout(.seconds(60), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }

    public func unsubscribe(wallet: Wallet) -> AnyPublisher<Bool, Never> {
        getOrCreateSubscriptionState(wallet: wallet)

        subscriptions[wallet.address]?.loadingState = .loading

        let unsubscribeSubject = PassthroughSubject<Bool, Never>()
        let cancellable = buildUnsubscribe(wallet: wallet)
            .handleEvents(receiveOutput: { [weak self] hasUnsubscribed in
                if hasUnsubscribed {
                    self?.isSubscribedStorage[wallet.address] = false
                    self?.subscriptions[wallet.address]?.subscription = nil
                }
            }, receiveCompletion: { [weak self] _ in
                self?.subscriptions[wallet.address]?.loadingState = .done(())
                self?.subscriptions[wallet.address]?.cancellable = nil
            }, receiveCancel: { [weak self] in
                self?.subscriptions[wallet.address]?.loadingState = .done(())
            })
            .multicast(subject: unsubscribeSubject)
            .connect()

        subscriptions[wallet.address]?.cancellable?.cancel()
        subscriptions[wallet.address]?.cancellable = cancellable

        return unsubscribeSubject.handleEvents(receiveCancel: { cancellable.cancel() })
            .eraseToAnyPublisher()
    }

    public func register(deviceToken: Result<Data, Error>) {
        guard Features.current.isAvailable(.areNotificationsEnabled) else { return }

        unUserNotificationService.register(deviceToken: deviceToken)
    }

    public func handle(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) async {
        guard Features.current.isAvailable(.areNotificationsEnabled) else { return }

        if let userInfo = launchOptions?[.remoteNotification] as? [String: AnyObject] {
            infoLog("[UNUserNotificationsService] handle launchOptions: \(launchOptions)")
            _ = await notificationHandler.process(userInfo: userInfo, appStartedFromPush: true)
        }
    }

    public func handle(remoteNotification userInfo: RemoteNotificationUserInfo) async -> UIBackgroundFetchResult {
        guard Features.current.isAvailable(.areNotificationsEnabled) else { return .noData }

        unUserNotificationService.handle(remoteNotification: userInfo)
        infoLog("[UNUserNotificationsService] Receive remote push notification: \(userInfo)")
        return await notificationHandler.process(userInfo: userInfo, appStartedFromPush: false)
    }
}
