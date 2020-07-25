// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

class HardcodedTokenCardTableSectionHeader: UIView {
    private let label = UILabel()
    private let topSeparatorView = UIView.tableHeaderFooterViewSeparatorView()
    private let bottomSeparatorView = UIView.tableHeaderFooterViewSeparatorView()

    override init(frame: CGRect) {
        super.init(frame: CGRect())

        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(topSeparatorView)
        addSubview(bottomSeparatorView)
        addSubview(label)

        let topConstraint = label.topAnchor.constraint(equalTo: topSeparatorView.bottomAnchor, constant: 20)
        let bottomConstraint = label.bottomAnchor.constraint(equalTo: bottomSeparatorView.topAnchor, constant: -20)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),

            topSeparatorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            topSeparatorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            topSeparatorView.topAnchor.constraint(equalTo: topAnchor),

            bottomSeparatorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomSeparatorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomSeparatorView.bottomAnchor.constraint(equalTo: bottomAnchor),

            topConstraint,
            bottomConstraint
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String) {
        backgroundColor = R.color.white()

        label.backgroundColor = R.color.white()
        label.textColor = R.color.black()
        label.font = Fonts.bold(size: 24)
        label.text = title
    }
}
