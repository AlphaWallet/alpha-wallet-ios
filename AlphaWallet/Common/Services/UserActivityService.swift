//
//  UserActivityService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.04.2023.
//

import Foundation
import AlphaWalletFoundation
import AlphaWalletLogger

protocol UserActivityHandler: AnyObject {
    func handle(_ userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool
}

class UserActivityService: UserActivityHandler {
    private let handlers: [UserActivityHandler]

    init(handlers: [UserActivityHandler]) {
        self.handlers = handlers
    }

    func handle(_ userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        var result: Bool = false
        for each in handlers {
            let isHandled = each.handle(userActivity, restorationHandler: restorationHandler)
            if isHandled {
                result = true
            }
        }

        return result
    }
}

protocol DonationUserActivityNavigatable: AnyObject {
    func showUniversalScanner(fromSource source: Analytics.ScanQRCodeSource)
    func showQrCode()
}

class DonationUserActivityHandler: UserActivityHandler {
    weak var navigation: DonationUserActivityNavigatable?
    private let analytics: AnalyticsLogger

    init(analytics: AnalyticsLogger) {
        self.analytics = analytics
    }

    func handle(_ userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if let type = userActivity.userInfo?[Donations.typeKey] as? String {
            infoLog("[Shortcuts] handleIntent type: \(type)")
            if type == CameraDonation.userInfoTypeValue {
                analytics.log(navigation: Analytics.Navigation.openShortcut, properties: [
                    Analytics.Properties.type.rawValue: Analytics.ShortcutType.camera.rawValue
                ])

                navigation?.showUniversalScanner(fromSource: .siriShortcut)
                return true
            }
            if type == WalletQrCodeDonation.userInfoTypeValue {
                analytics.log(navigation: Analytics.Navigation.openShortcut, properties: [
                    Analytics.Properties.type.rawValue: Analytics.ShortcutType.walletQrCode.rawValue
                ])
                navigation?.showQrCode()
                return true
            }
        }
        return false
    }
}
