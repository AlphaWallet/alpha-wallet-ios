// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

extension TokensViewController {
    class TableViewSectionHeader: UITableViewHeaderFooterView {
        static let reuseIdentifier = String(describing: TableViewSectionHeader.self)

        var filterView: SegmentedControl? {
            didSet {
                guard let filterView = filterView else {
                    if let oldValue = oldValue {
                        oldValue.removeFromSuperview()
                    }
                    return
                }
                filterView.translatesAutoresizingMaskIntoConstraints = false
                contentView.addSubview(filterView)
                NSLayoutConstraint.activate([
                    filterView.anchorsConstraint(to: contentView, edgeInsets: .init(top: 0, left: 0, bottom: 7, right: 0)),
                ])
            }
        }

        override init(reuseIdentifier: String?) {
            super.init(reuseIdentifier: reuseIdentifier)
            contentView.backgroundColor = GroupedTable.Color.background
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
