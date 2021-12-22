// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol ReusableTableHeaderViewType: UIView, WithReusableIdentifier {

}

extension TokensViewController {

    class GeneralTableViewSectionHeader<T: ReusableTableHeaderViewType>: UITableViewHeaderFooterView {
        private var snapConstraints: [NSLayoutConstraint] = []
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
                NSLayoutConstraint.deactivate(snapConstraints)

                snapConstraints = subview.anchorsConstraint(to: contentView) +
                topSeparator.anchorSeparatorToTop(to: contentView) +
                bottomSeparator.anchorSeparatorToBottom(to: contentView)

                NSLayoutConstraint.activate(snapConstraints)
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

        var useSeparatorTopLine: Bool {
            get {
                !topSeparator.isHidden
            }
            set {
                topSeparator.isHidden = !newValue
            }
        }

        var useSeparatorBottomLine: Bool {
            get {
                !bottomSeparator.isHidden
            }
            set {
                bottomSeparator.isHidden = !newValue
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

    class ContainerView<T: UIView>: UIView {
        private var snapConstraints: [NSLayoutConstraint] = []
        var subview: T {
            didSet {
                stackView.removeAllArrangedSubviews()
                stackView.addArrangedSubviews([topSeparator, subview, bottomSeparator])
            }
        }

        private (set) var bottomSeparator: UIView = {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false

            return view
        }()

        private (set) var topSeparator: UIView = {
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

        private let stackView: UIStackView = [].asStackView(axis: .vertical)

        init(subview: T) {
            self.subview = subview

            super.init(frame: .zero)
            stackView.translatesAutoresizingMaskIntoConstraints = false
            backgroundColor = Colors.appWhite
            bottomSeparator.isHidden = true
            topSeparator.isHidden = true

            bottomSeparator.backgroundColor = GroupedTable.Color.cellSeparator
            topSeparator.backgroundColor = GroupedTable.Color.cellSeparator

            addSubview(stackView)

            NSLayoutConstraint.activate([
                topSeparator.heightAnchor.constraint(equalToConstant: 1),
                bottomSeparator.heightAnchor.constraint(equalToConstant: 1),
                stackView.anchorsConstraint(to: self)
            ])

            stackView.addArrangedSubviews([topSeparator, subview, bottomSeparator])
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
