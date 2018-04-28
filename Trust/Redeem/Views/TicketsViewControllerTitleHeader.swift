// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class TicketsViewControllerTitleHeader: UIView {
    let background = UIView()
    let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)

        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let stackView = [titleLabel].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stackView)

        let backgroundWidthConstraint = background.widthAnchor.constraint(equalTo: widthAnchor)
        backgroundWidthConstraint.priority = .defaultHigh
        // TODO extract constant. Maybe StyleLayout.sideMargin
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
//            background.topAnchor.constraint(equalTo: topAnchor),
            background.centerYAnchor.constraint(equalTo: centerYAnchor),
            backgroundWidthConstraint,

            stackView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 21),
            stackView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -21),
            stackView.topAnchor.constraint(equalTo: background.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -16),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String) {
        frame = CGRect(x: 0, y: 0, width: 300, height: 90)
        backgroundColor = Colors.appWhite

        titleLabel.textColor = Colors.appText
        titleLabel.font = Fonts.light(size: 25)!
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.text = title
    }
}