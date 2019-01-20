// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct DappsHomeViewControllerHeaderViewViewModel {
    let isEditing: Bool

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var title: String {
        return R.string.localizable.dappBrowserTitle()
    }

    var myDappsButtonImage: UIImage? {
        return R.image.myDapps()
    }

    var myDappsButtonTitle: String {
        return R.string.localizable.myDappsButtonImageLabel()
    }

    var discoverButtonImage: UIImage? {
        return R.image.discoverDapps()
    }

    var discoverButtonTitle: String {
        return R.string.localizable.discoverDappsButtonImageLabel()
    }

    var historyButtonImage: UIImage? {
        return R.image.history()
    }

    var historyButtonTitle: String {
        return R.string.localizable.historyButtonImageLabel()
    }
}
