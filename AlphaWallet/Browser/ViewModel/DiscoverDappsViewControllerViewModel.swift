// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

struct DiscoverDappsViewControllerViewModel {

    var dappCategories = Dapps.categorisedDapps

    var dapps = Dapps.masterList

    var backgroundColor: UIColor {
        return Colors.appWhite
    }
}
