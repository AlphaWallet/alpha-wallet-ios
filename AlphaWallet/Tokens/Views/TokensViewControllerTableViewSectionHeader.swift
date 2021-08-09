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
                contentView.addSubview(bottomSeparator)
                contentView.addSubview(topSeparator)
                
                NSLayoutConstraint.activate([
                    subview.anchorsConstraint(to: contentView),
                ] + topSeparator.anchorSeparatorToTop(to: contentView) + bottomSeparator.anchorSeparatorToBottom(to: contentView))
            }
        }

        private var bottomSeparator: UIView = {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false

            return view
        }()

        private var topSeparator: UIView = {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false

            return view
        }()

        var useSeparatorLine: Bool {
            get {
                !bottomSeparator.isHidden
            }
            set {
                bottomSeparator.isHidden = !newValue
                topSeparator.isHidden = !newValue
            }
        }

        override var reuseIdentifier: String? {
            T.reusableIdentifier
        }

        override init(reuseIdentifier: String?) {
            super.init(reuseIdentifier: reuseIdentifier)

            contentView.backgroundColor = Colors.appWhite
            bottomSeparator.isHidden = true
            topSeparator.isHidden = true

            bottomSeparator.backgroundColor = GroupedTable.Color.cellSeparator
            topSeparator.backgroundColor = GroupedTable.Color.cellSeparator
        }

        required init?(coder aDecoder: NSCoder) {
            return nil
        }
    }
}

extension UIView {
    func anchorSeparatorToTop(to superView: UIView) -> [NSLayoutConstraint] {
        return [
            centerXAnchor.constraint(equalTo: superView.centerXAnchor),
            widthAnchor.constraint(equalTo: superView.widthAnchor),
            heightAnchor.constraint(equalToConstant: GroupedTable.Metric.cellSeparatorHeight),
            topAnchor.constraint(equalTo: superView.topAnchor)
        ]
    }

    func anchorSeparatorToBottom(to superView: UIView) -> [NSLayoutConstraint] {
        return [
            centerXAnchor.constraint(equalTo: superView.centerXAnchor),
            widthAnchor.constraint(equalTo: superView.widthAnchor),
            heightAnchor.constraint(equalToConstant: GroupedTable.Metric.cellSeparatorHeight),
            bottomAnchor.constraint(equalTo: superView.bottomAnchor)
        ]
    }
}
