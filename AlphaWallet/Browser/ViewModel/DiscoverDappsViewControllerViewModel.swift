// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct DiscoverDappsViewControllerViewModel {

    var dappCategories = Dapps.categorisedDapps

    var dapps = Dapps.masterList

    var backgroundColor: UIColor {
        return Colors.appWhite
    }
}
