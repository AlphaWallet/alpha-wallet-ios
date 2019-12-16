// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol TokenViewControllerHeaderViewDelegate: class {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, inHeaderView: TokenViewControllerHeaderView)
    func didPressViewWebPage(url: URL, inHeaderView: TokenViewControllerHeaderView)
}

class TokenViewControllerHeaderView: UIView {
    private let contract: AlphaWallet.Address
    private let recentTransactionsLabel = UILabel()
    private let recentTransactionsLabelBorders = (top: UIView(), bottom: UIView())
    private let spacers = (beforeTokenScriptFileStatus: UIView.spacer(height: 20), ())
    private let tokenScriptFileStatusStackView = [].asStackView()

    let sendHeaderView = SendHeaderView()
    var tokenScriptFileStatus: TokenLevelTokenScriptDisplayStatus? {
        didSet {
            for each in tokenScriptFileStatusStackView.subviews {
                each.removeFromSuperview()
            }
            tokenScriptFileStatusStackView.isHidden = true
            spacers.beforeTokenScriptFileStatus.isHidden = true
            guard let tokenScriptFileStatus = tokenScriptFileStatus else { return }
            switch tokenScriptFileStatus {
            case .type0NoTokenScript:
                return
            case .type1GoodTokenScriptSignatureGoodOrOptional, .type2BadTokenScript:
                let button = createTokenScriptFileStatusButton(withStatus: tokenScriptFileStatus, urlOpener: self)
                tokenScriptFileStatusStackView.addArrangedSubviews([.spacerWidth(37), button, .spacerWidth(1, flexible: true)])
                tokenScriptFileStatusStackView.isHidden = false
                spacers.beforeTokenScriptFileStatus.isHidden = false
            }
        }
    }
    weak var delegate: TokenViewControllerHeaderViewDelegate?

    init(contract: AlphaWallet.Address) {
        self.contract = contract
        super.init(frame: .zero)

        sendHeaderView.delegate = self

        let recentTransactionsLabelHolder = UIView()
        recentTransactionsLabelHolder.backgroundColor = GroupedTable.Color.background
        recentTransactionsLabel.translatesAutoresizingMaskIntoConstraints = false
        recentTransactionsLabelHolder.addSubview(recentTransactionsLabel)

        let stackView = [
            spacers.beforeTokenScriptFileStatus,
            tokenScriptFileStatusStackView,
            sendHeaderView,
            recentTransactionsLabelBorders.top,
            recentTransactionsLabelHolder,
            recentTransactionsLabelBorders.bottom,
            .spacer(height: 7),
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            recentTransactionsLabelBorders.top.heightAnchor.constraint(equalToConstant: 1),
            recentTransactionsLabelBorders.bottom.heightAnchor.constraint(equalToConstant: 1),

            recentTransactionsLabelHolder.heightAnchor.constraint(equalToConstant: 50),
            recentTransactionsLabel.anchorsConstraint(to: recentTransactionsLabelHolder, edgeInsets: .init(top: 0, left: 30, bottom: 0, right: 0)),

            stackView.anchorsConstraint(to: self, edgeInsets: .init(top: 0, left: 0, bottom: 0, right: 0)),
        ])

        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        recentTransactionsLabel.textColor = .init(red: 118, green: 118, blue: 118)
        recentTransactionsLabel.font = Fonts.semibold(size: 15)
        recentTransactionsLabel.text = R.string.localizable.recentTransactions()

        recentTransactionsLabelBorders.top.backgroundColor = UIColor(red: 236, green: 236, blue: 236)
        recentTransactionsLabelBorders.bottom.backgroundColor = UIColor(red: 236, green: 236, blue: 236)
    }

    @objc private func showContractWebPage() {
        delegate?.didPressViewContractWebPage(forContract: contract, inHeaderView: self)
    }
}

extension TokenViewControllerHeaderView: CanOpenURL2 {
    func open(url: URL) {
        delegate?.didPressViewWebPage(url: url, inHeaderView: self)
    }
}

extension TokenViewControllerHeaderView: SendHeaderViewDelegate {
    func didPressViewContractWebPage(inHeaderView: SendHeaderView) {
        showContractWebPage()
    }
}
