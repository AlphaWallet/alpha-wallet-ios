//
//  SelfResizedTextView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.03.2021.
//

import UIKit

class SelfResizedTextView: UITextView {

    lazy var heightConstraint: NSLayoutConstraint = {
        let constraint = self.heightAnchor.constraint(equalToConstant: 0)
        constraint.priority = .defaultHigh
        return constraint
    }()
    private var scrollViewContentSizeObserver: NSKeyValueObservation?

    init() {
        super.init(frame: .zero, textContainer: nil)

        self.translatesAutoresizingMaskIntoConstraints = false
        scrollViewContentSizeObserver = self.observe(\SelfResizedTextView.contentSize, options: [.new]) { [weak self] (_, change) in
            guard let strongSelf = self, let newSize = change.newValue else { return }
            strongSelf.heightConstraint.constant = newSize.height
        }
    }

    required init?(coder: NSCoder) {
        return nil
    }
}
