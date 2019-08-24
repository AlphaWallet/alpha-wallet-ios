// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

class SettingsHeaderView: UIView {
    private let titleLabel = UILabel()

    var title: String? {
        get {
            return titleLabel.text
        }
        set {
            titleLabel.text = newValue
            layoutIfNeeded()
        }
    }

    init() {
        //TODO remove duplicate of TransactionsViewController.headerView(for:)
        super.init(frame: .zero)

        titleLabel.textColor = Colors.appWhite
        titleLabel.font = Fonts.regular(size: 16)!
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.anchorsConstraint(to: self, edgeInsets: .init(top: 0, left: 20, bottom: 0, right: 0)),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
