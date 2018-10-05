// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import UserNotifications

class PushNotificationsCoordinator: NSObject, Coordinator {
    var coordinators: [Coordinator] = []
    private var notificationCenter: UNUserNotificationCenter {
        return .current()
    }

    func start() {
        notificationCenter.delegate = self
    }

    func didShowWallet(in navigationController: UINavigationController) {
        promptToEnableNotification(in: navigationController)
    }

    private func promptToEnableNotification(in navigationController: UINavigationController) {
        authorizationNotDetermined {
            navigationController.visibleViewController?.confirm(
                    title: R.string.localizable.transactionsReceivedEtherNotificationPrompt(),
                    message: nil,
                    okTitle: R.string.localizable.oK(),
                    okStyle: .default
            ) { result in
                switch result {
                case .success:
                    //Give some time for the view controller to show up first. We don't have to be precise, so no need to complicate things with hooking up to the view controller's animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.requestForAuthorization()
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
            if (granted) {
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
