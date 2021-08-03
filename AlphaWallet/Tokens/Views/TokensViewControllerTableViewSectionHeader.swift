// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol ReusableTableHeaderViewType: UIView, WithReusableIdentifier {

}

extension TokensViewController {
    class TableViewSectionHeader: UITableViewHeaderFooterView {
        var filterView: SegmentedControl? {
            didSet {
                guard let filterView = filterView else {
                    if let oldValue = oldValue {
                        oldValue.removeFromSuperview()
                    }
                    return
                }
                filterView.backgroundColor = Colors.appWhite
                filterView.translatesAutoresizingMaskIntoConstraints = false
                contentView.addSubview(filterView)
                NSLayoutConstraint.activate([
                    filterView.anchorsConstraint(to: contentView),
                ])
            }
        }

        override init(reuseIdentifier: String?) {
            super.init(reuseIdentifier: reuseIdentifier)
            contentView.backgroundColor = Colors.appWhite
        }

        required init?(coder aDecoder: NSCoder) {
            return nil
        }
    }

    class GeneralTableViewSectionHeader<T: ReusableTableHeaderViewType>: UITableViewHeaderFooterView {
        var subview: T? {
            didSet {
                guard let subview = subview else {
                    if let oldValue = oldValue {
                        oldValue.removeFromSuperview()
                    }
                    return
                }
                subview.backgroundColor = Colors.appWhite
                subview.translatesAutoresizingMaskIntoConstraints = false
                contentView.addSubview(subview)
                NSLayoutConstraint.activate([
                    subview.anchorsConstraint(to: contentView),
                ])
            }
        }

        override var reuseIdentifier: String? {
            subview?.restorationIdentifier
        }

        override init(reuseIdentifier: String?) {
            super.init(reuseIdentifier: reuseIdentifier)
            contentView.backgroundColor = Colors.appWhite
        }

        required init?(coder aDecoder: NSCoder) {
            return nil
        }
    }
}
