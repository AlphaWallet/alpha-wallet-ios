// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import TrustKeystore

//TODO create view model to clean up
class NativeCryptoCurrencyBalanceView: UIView {
    var session: WalletSession {
        didSet {
            configure()
            balanceCoordinator = GetBalanceCoordinator(forServer: server)
            refreshWalletBalance()
        }
    }
    private let rightMargin: CGFloat
    private var balances: [Address: Balance] = [:]
    //TODO should let someone else fetch the balance instead of doing it here
    private lazy var balanceCoordinator = GetBalanceCoordinator(forServer: server)
    private let label = UILabel()

    private var server: RPCServer {
        return session.server
    }

    private var attributedBalanceText: NSAttributedString {
        let amount = balances[session.account.address]?.amountShort ?? "--"
        return amountAttributedString(for: amount)
    }

    var topMargin: CGFloat {
        didSet {
            configure()
        }
    }

    init(session: WalletSession, rightMargin: CGFloat, topMargin: CGFloat) {
        self.session = session
        self.rightMargin = rightMargin
        self.topMargin = topMargin

        super.init(frame: .zero)

        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        float()
        refreshWalletBalance()
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        label.attributedText = attributedBalanceText

        let size = label.intrinsicContentSize
        let currentWindow = UIApplication.shared.keyWindow!
        frame = .init(x: currentWindow.frame.width - size.width - rightMargin, y: topMargin, width: size.width, height: size.height)
    }

    private func float() {
        isHidden = true
        let currentWindow = UIApplication.shared.keyWindow
        currentWindow?.addSubview(self)
    }

    func show() {
        isHidden = false
    }

    func hide() {
        isHidden = true
    }

    private func refreshWalletBalance() {
        let address = session.account.address
        balanceCoordinator.getEthBalance(for: address, completion: { [weak self] (result) in
            guard let strongSelf = self else { return }
            strongSelf.balances[address] = result.value
            strongSelf.configure()
        })
    }

    private func amountAttributedString(for value: String) -> NSAttributedString {
        let amount = NSAttributedString(
                string: value,
                attributes: [
                    .font: Fonts.regular(size: 14) as Any,
                ]
        )
        let currency = NSAttributedString(
                string: " " + server.symbol,
                attributes: [
                    .font: Fonts.regular(size: 14) as Any,
                    .foregroundColor: Colors.appBackground,
                ]
        )
        return amount + currency
    }
}
