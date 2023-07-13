//
//  UNUserNotificationsService.swift
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

public protocol SystemSettingsRequestable: AnyObject {
    @MainActor func promptOpenSettings() async -> Result<Void, Error>
}

//NOTE: its not able to be delegate of UNUserNotificationCenter by setting UNUserNotificationCenter.current().delegate = self,
public final class UNUserNotificationsService: NSObject {
    private let application: UIApplication
    private let notificationCenter: UNUserNotificationCenter = .current()
    private weak var systemSettingsRequestable: SystemSettingsRequestable?
    private var cancellable = Set<AnyCancellable>()

    @Published public private(set) var settings: Loadable<UNNotificationSettings, Error> = .loading

    public init(application: UIApplication,
                systemSettingsRequestable: SystemSettingsRequestable) {

        self.systemSettingsRequestable = systemSettingsRequestable
        self.application = application
        super.init()

        registerForReceivingRemoteNotifications()
        updateAuthorizationStatus()

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink(receiveValue: { [weak self] _ in self?.updateAuthorizationStatus() })
            .store(in: &cancellable)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink(receiveValue: { [weak self] _ in self?.updateAuthorizationStatus() })
            .store(in: &cancellable)
    }

    private func updateAuthorizationStatus() {
        Task { @MainActor in
            self.settings = .done(await notificationCenter.notificationSettings())
        }
    }

    private func registerForReceivingRemoteNotifications() {
        application.applicationIconBadgeNumber = 0

        guard Features.current.isAvailable(.areNotificationsEnabled) else { return }
        Messaging.messaging().delegate = self
    }

    public func subscribe(to topic: String) -> AnyPublisher<Bool, Never> {
        return Future { try await Messaging.messaging().subscribe(toTopic: topic) }
            .map { _ in true }
            .replaceError(with: false)
            .eraseToAnyPublisher()
    }

    public func unsubscribe(from topic: String) -> AnyPublisher<Bool, Never> {
        return Future { try await Messaging.messaging().unsubscribe(fromTopic: topic) }
            .map { _ in true }
            .replaceError(with: false)
            .eraseToAnyPublisher()
    }

    public func register(deviceToken: Result<Data, Error>) {
        guard case .success(let deviceToken) = deviceToken else { return }
        infoLog("[UNUserNotificationsService] register device token: \(deviceToken)")

        Messaging.messaging().apnsToken = deviceToken
    }

    public func handle(remoteNotification userInfo: RemoteNotificationUserInfo) {
        Messaging.messaging().appDidReceiveMessage(userInfo)
    }

    @MainActor public func requestAuthorization() async -> Bool {
        let result = await requestForAuthorization()
        switch result {
        case .success(let granted):
            if granted {
                return granted
            } else {
                guard case .success = await systemSettingsRequestable?.promptOpenSettings() else { return false }
                guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return false }

                if application.canOpenURL(settingsUrl) {
                    application.open(settingsUrl) { _ in }
                }
                return false
            }
        case .failure:
            return false
        }
    }

    @MainActor public func requestToEnableNotification() async {
        await requestForAuthorization()
    }

    @MainActor public func unregisterRemoteNotifications() async -> Bool {
        application.unregisterForRemoteNotifications()

        infoLog("[UNUserNotificationsService] unregister remote notifications")
        settings = .done(await notificationCenter.notificationSettings())
        return true
    }

    @MainActor @discardableResult private func requestForAuthorization() async -> Result<Bool, Error> {
        struct UNAuthorizationError: Error {
            let message: String
        }
        infoLog("[UNUserNotificationsService] requestForAuthorization")
        do {
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            let granted = try await notificationCenter.requestAuthorization(options: authOptions)
            let settings = await notificationCenter.notificationSettings()
            self.settings = .done(settings)

            if granted {
                guard settings.authorizationStatus == .authorized else {
                    return .failure(UNAuthorizationError(message: ""))
                }

                application.registerForRemoteNotifications()

                return .success(true)
            } else {
                return .success(false)
            }
        } catch {
            return .failure(error)
        }
    }
}

extension UNUserNotificationsService: MessagingDelegate {

    public func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        infoLog("[UNUserNotificationsService] Firebase registration token: \(fcmToken ?? "-")")
    }
}
