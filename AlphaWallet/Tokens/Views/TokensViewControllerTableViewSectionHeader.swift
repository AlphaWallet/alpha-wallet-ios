// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

extension TokensViewController {
    class TableViewSectionHeader: UITableViewHeaderFooterView {
        static let reuseIdentifier = String(describing: TableViewSectionHeader.self)

        var filterView: WalletFilterView? {
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
                    filterView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                    filterView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                    filterView.topAnchor.constraint(equalTo: contentView.topAnchor),
                    filterView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -7),
                ])
            }
        }

        override init(reuseIdentifier: String?) {
            super.init(reuseIdentifier: reuseIdentifier)
            contentView.backgroundColor = Colors.appBackground
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
