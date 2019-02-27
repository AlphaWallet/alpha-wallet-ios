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

        stackView.anchor(to: self, margin: 15)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(amount: NSAttributedString) {
        amountLabel.attributedText = amount

        blockchainLabel.textAlignment = .center
        blockchainLabel.cornerRadius = 7
        blockchainLabel.backgroundColor = server.blockChainNameColor
        blockchainLabel.textColor = Colors.appWhite
        blockchainLabel.font = Fonts.semibold(size: 12)!
        blockchainLabel.text = " \(server.name)     "
    }
}
