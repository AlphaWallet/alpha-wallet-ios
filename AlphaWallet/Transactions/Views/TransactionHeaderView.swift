// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

class TransactionHeaderView: UIView {
    private let server: RPCServer
    private let amountLabel = UILabel()
    private let blockchainLabel = UILabel()

    init(server: RPCServer) {
        self.server = server
        super.init(frame: .zero)

        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        amountLabel.textAlignment = .center

        let stackView = [
            blockchainLabel,
            amountLabel,
        ].asStackView(axis: .vertical, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        let margin = CGFloat(15)
        NSLayoutConstraint.activate([
            blockchainLabel.heightAnchor.constraint(equalToConstant: Screen.TokenCard.Metric.blockChainTagHeight),

            stackView.topAnchor.constraint(equalTo: topAnchor, constant: margin),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -margin),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -margin),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: margin),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(amount: NSAttributedString) {
        amountLabel.attributedText = amount

        blockchainLabel.textAlignment = .center
        blockchainLabel.cornerRadius = 7
        blockchainLabel.backgroundColor = server.blockChainNameColor
        blockchainLabel.textColor = Screen.TokenCard.Color.blockChainName
        blockchainLabel.font = Screen.TokenCard.Font.blockChainName
        blockchainLabel.text = " \(server.name)     "
    }
}
