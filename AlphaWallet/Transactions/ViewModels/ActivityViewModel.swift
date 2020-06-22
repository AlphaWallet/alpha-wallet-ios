// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import BigInt

struct ActivityViewModel {
    let activity: Activity

    var title: String {
        R.string.localizable.activityTabbarItemTitle()
    }

    var backgroundColor: UIColor {
        Screen.TokenCard.Color.background
    }
}
