// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

class TransactionsFooterView: UIView {

    lazy var sendButton: UIButton = {
        let sendButton = UIButton(type: .system)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setTitle(NSLocalizedString("Send", value: "Send", comment: ""), for: .normal)
        return sendButton
    }()

    lazy var requestButton: UIButton = {
        let requestButton = UIButton(type: .system)
        requestButton.translatesAutoresizingMaskIntoConstraints = false
        requestButton.setTitle(R.string.localizable.transactionsReceiveButtonTitle(), for: .normal)
        return requestButton
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        let stackView = UIStackView(arrangedSubviews: [
            sendButton,
            requestButton,
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

        requestButton.setTitleColor(Colors.appWhite, for: .normal)
        requestButton.backgroundColor = Colors.appHighlightGreen
        requestButton.titleLabel?.font = Fonts.regular(size: 20)!
    }
}
