// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

class TransactionsFooterView: UIView {

    lazy var sendButton: UIButton = {
        let sendButton = UIButton(type: .system)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setTitle(R.string.localizable.aSendReceiveButtonTitle(), for: .normal)
        return sendButton
    }()


    override init(frame: CGRect) {
        super.init(frame: frame)

        let stackView = UIStackView(arrangedSubviews: [
            sendButton,
        ])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.distribution = .fillEqually
        stackView.spacing = 0
        addSubview(stackView)

        backgroundColor = Colors.appHighlightGreen

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
		sendButton.setTitleColor(Colors.appWhite, for: .normal)
        sendButton.backgroundColor = Colors.appHighlightGreen
        sendButton.titleLabel?.font = Fonts.regular(size: 20)!
    }
}
