// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import PromiseKit

//TODO create view model to clean up
class NativeCryptoCurrencyBalanceView: UIView {
    var session: WalletSession {
        didSet {
            configure()
            balanceCoordinator = GetNativeCryptoCurrencyBalanceCoordinator(forServer: server)
            refreshWalletBalance()
        }
    }
    private let rightMargin: CGFloat
    private var balances: [AlphaWallet.Address: Balance] = [:]
    //TODO should let someone else fetch the balance instead of doing it here
    private lazy var balanceCoordinator = GetNativeCryptoCurrencyBalanceCoordinator(forServer: server)
    private let label = UILabel()
    private let horizontalMarginAroundLabel = CGFloat(7)
    private let verticalMarginAroundLabel = CGFloat(4)

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

    private var desiredSizeBasedOnLabelInstrinsicContentSize: CGSize {
        let size = label.intrinsicContentSize
        return .init(width: size.width + horizontalMarginAroundLabel * 2, height: size.height + verticalMarginAroundLabel * 2)
    }

    init(session: WalletSession, rightMargin: CGFloat, topMargin: CGFloat) {
        self.session = session
        self.rightMargin = rightMargin
        self.topMargin = topMargin

        super.init(frame: .zero)

        //So we can tap through to the content in the dapp browser
        isUserInteractionEnabled = false

        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalMarginAroundLabel),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -horizontalMarginAroundLabel),
            label.topAnchor.constraint(equalTo: topAnchor, constant: verticalMarginAroundLabel ),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -verticalMarginAroundLabel),
        ])

        float()
        refreshWalletBalance()
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        backgroundColor = Colors.appWhite
        alpha = 0.7
        cornerRadius = 3

        label.attributedText = attributedBalanceText

        let size = desiredSizeBasedOnLabelInstrinsicContentSize
        let currentWindow = UIApplication.shared.firstKeyWindow!
        frame = .init(x: currentWindow.frame.width - size.width - rightMargin, y: topMargin, width: size.width, height: size.height)
    }

    private func float() {
        isHidden = true
        let currentWindow = UIApplication.shared.firstKeyWindow
        currentWindow?.addSubview(self)
    }

    func hide() {
        isHidden = true
    }

    private func refreshWalletBalance() {
        let address = session.account.address
        firstly {
            balanceCoordinator.getBalance(for: address)
        }.done { [weak self] result in
            self?.balances[address] = result
        }.catch { [weak self] _ in
            self?.balances[address] = nil
        }.finally { [weak self] in
            self?.configure()
        }
    }

    private func amountAttributedString(for value: String) -> NSAttributedString {
        return NSAttributedString(
                string: "\(value) \(server.symbol)",
                attributes: [
                    .font: Fonts.semibold(size: 12) as Any,
                    .foregroundColor: UIColor(red: 71, green: 71, blue: 71)
                ]
        )
    }
}
