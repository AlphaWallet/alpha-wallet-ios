// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import UserNotifications

class PushNotificationsCoordinator: NSObject, Coordinator {
    private let server: RPCServer
    private var notificationCenter: UNUserNotificationCenter {
        return .current()
    }

    var coordinators: [Coordinator] = []

    init(server: RPCServer) {
        self.server = server
        super.init()
    }

    func start() {
        notificationCenter.delegate = self
    }

    func didShowWallet(in navigationController: UINavigationController) {
        promptToEnableNotification(in: navigationController)
    }

    private func promptToEnableNotification(in navigationController: UINavigationController) {
        authorizationNotDetermined { [weak self] in
            guard let strongSelf = self else { return }
            navigationController.visibleViewController?.confirm(
                    title: R.string.localizable.transactionsReceivedEtherNotificationPrompt(strongSelf.server.cryptoCurrencyName),
                    message: nil,
                    okTitle: R.string.localizable.oK(),
                    okStyle: .default
            ) { result in
                switch result {
                case .success:
                    //Give some time for the view controller to show up first. We don't have to be precise, so no need to complicate things with hooking up to the view controller's animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                        guard let strongSelf = self else { return }
                        strongSelf.requestForAuthorization()
                    }
                case .failure:
                    break
                }
            }
        }
    }

    private func authorizationNotDetermined(handler: @escaping () -> Void) {
        notificationCenter.getNotificationSettings { settings in
            if case .notDetermined = settings.authorizationStatus {
                handler()
            }
        }
    }

    //TODO call this after send Ether too?
    private func requestForAuthorization() {
        notificationCenter.requestAuthorization(options: [.badge, .alert, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async(execute: {
                    UIApplication.shared.registerForRemoteNotifications()
                })
            } else {
                //Do stuff if unsuccessful…
            }
        }
    }
}

extension PushNotificationsCoordinator: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.badge, .alert, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
