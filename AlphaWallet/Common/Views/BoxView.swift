// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

///Wrap a child view and add insets around it. Useful for UITableView header/footers
class BoxView<T: UIView>: UIView {
    let view: T
    private var leftConstraint: NSLayoutConstraint?
    private var rightConstraint: NSLayoutConstraint?
    private var topConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?

    var insets: UIEdgeInsets {
        didSet {
            updateConstraintsConstants()
        }
    }

    init(view: T, insets: UIEdgeInsets = .zero) {
        self.view = view
        self.insets = insets
        super.init(frame: .zero)

        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        leftConstraint = view.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0)
        rightConstraint = trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0)
        topConstraint = view.topAnchor.constraint(equalTo: topAnchor, constant: 0)
        bottomConstraint = bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0)
        if let leftConstraint = leftConstraint, let rightConstraint = rightConstraint, let topConstraint = topConstraint, let bottomConstraint = bottomConstraint {
            NSLayoutConstraint.activate([leftConstraint, rightConstraint, topConstraint, bottomConstraint])
        }
        updateConstraintsConstants()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateConstraintsConstants() {
        leftConstraint?.constant = insets.left
        rightConstraint?.constant = insets.right
        topConstraint?.constant = insets.top
        bottomConstraint?.constant = insets.bottom
    }
}
