// Copyright © 2023 Stormbird PTE. LTD.

import CoreSpotlight
import Foundation
import AlphaWalletLogger

class CameraDonation {
    //TODO maybe change to include wallet address
    private static let persistentIdentifier: NSUserActivityPersistentIdentifier = activityType
    //Matches `Info.plist` entry
    private static let activityType = "com.alphawallet.camera"

    //Because donating a shortcut is asynchronous, the NSUserActivity has to be kept alive for a bit
    private var userActivity: NSUserActivity?
    //Because donating a shortcut is asynchronous, the NSUserActivity has to be kept alive for a bit. We keep a strong reference to self for a short while to ensure that so client code doesn't have to
    private var selfReference: CameraDonation?

    static let userInfoTypeValue = "cameraDonation"

    init() {
        selfReference = self
        Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
            self.selfReference = nil
        }
    }

    func donate() {
        let activity = NSUserActivity(activityType: Self.activityType)
        activity.title = R.string.localizable.donateShortcutsCamera()
        let userInfo = [Donations.typeKey: Self.userInfoTypeValue]
        activity.addUserInfoEntries(from: userInfo)
        activity.requiredUserInfoKeys = [Donations.typeKey]
        activity.isEligibleForPrediction = true
        activity.isEligibleForSearch = true
        activity.persistentIdentifier = Self.persistentIdentifier
        self.userActivity = activity
        activity.becomeCurrent()
        infoLog("[Shortcuts] donated \(Self.persistentIdentifier) userInfo: \(userInfo)")
    }

    //For development only
    func delete() {
        infoLog("[Shortcuts] Deleting donated shortcut: \(Self.persistentIdentifier)…")
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [Self.persistentIdentifier])
        NSUserActivity.deleteSavedUserActivities(withPersistentIdentifiers: [Self.persistentIdentifier]) {
            infoLog("[Shortcuts] Deleted donated shortcut: \(Self.persistentIdentifier)")
        }
    }
}
