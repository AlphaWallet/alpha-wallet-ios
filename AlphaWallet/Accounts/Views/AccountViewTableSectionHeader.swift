// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

class AccountViewTableSectionHeader: UIView {
    enum HeaderType: Int {
        case hdWallet = 0
        case keystoreWallet = 1
        case watchedWallet = 2

        var title: String {
            switch self {
            case .hdWallet:
                return R.string.localizable.walletTypesHdWallets()
            case .keystoreWallet:
                return R.string.localizable.walletTypesKeystoreWallets()
            case .watchedWallet:
                return R.string.localizable.walletTypesWatchedWallets()
            }
        }
    }

    private let label = UILabel()
    private var topConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var constraintsWhenVisible: [NSLayoutConstraint]?

    override init(frame: CGRect) {
        super.init(frame: CGRect())

        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        let topConstraint = label.topAnchor.constraint(equalTo: topAnchor, constant: 7)
        let bottomConstraint = label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7)
        let constraintsWhenVisible = [
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            topConstraint,
            bottomConstraint
        ]

        NSLayoutConstraint.activate(constraintsWhenVisible)

        self.topConstraint = topConstraint
        self.bottomConstraint = bottomConstraint
        //UIKit doesn't like headers with a height of 0
        self.heightConstraint = heightAnchor.constraint(equalToConstant: 1)
        self.constraintsWhenVisible = constraintsWhenVisible
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(type: HeaderType, shouldHide: Bool) {
        backgroundColor  = GroupedTable.Color.background

        label.backgroundColor = GroupedTable.Color.background
        label.textColor = GroupedTable.Color.title
        label.font = Fonts.tableHeader
        label.text = type.title
        label.isHidden = shouldHide

        heightConstraint?.isActive = shouldHide
        if shouldHide {
            NSLayoutConstraint.deactivate(constraintsWhenVisible!)
        } else {
            NSLayoutConstraint.activate(constraintsWhenVisible!)
        }

        switch type {
        case .hdWallet:
            topConstraint?.constant = 0
            bottomConstraint?.constant = 0
        case .keystoreWallet:
            topConstraint?.constant = 4
            bottomConstraint?.constant = -16
        case .watchedWallet:
            topConstraint?.constant = 4
            bottomConstraint?.constant = -16
        }
    }
}