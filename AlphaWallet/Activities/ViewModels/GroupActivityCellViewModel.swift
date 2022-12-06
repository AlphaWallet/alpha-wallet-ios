// Copyright © 2021 Stormbird PTE. LTD.

import UIKit

struct GroupActivityCellViewModel {
    enum GroupType {
        case swap
        case unknown
    }

    let groupType: GroupType

    var contentsBackgroundColor: UIColor {
        Configuration.Color.Semantic.tableViewCellBackground
    }

    var backgroundColor: UIColor {
        Configuration.Color.Semantic.tableViewCellBackground
    }

    var titleTextColor: UIColor {
        Configuration.Color.Semantic.defaultForegroundText
    }

    var title: NSAttributedString {
        switch groupType {
        case .swap:
            return NSAttributedString(string: R.string.localizable.activityGroupTransactionSwap())
        case .unknown:
            return NSAttributedString(string: R.string.localizable.activityGroupTransactionUnknown())
        }
    }

    var leftMargin: CGFloat {
        DataEntry.Metric.sideMargin
    }
}
