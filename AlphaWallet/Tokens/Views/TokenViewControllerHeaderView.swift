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
    private let border = UIView()
    private let tokenScriptFileStatusStackView = [].asStackView()

    let sendHeaderView = SendHeaderView()
    var tokenScriptFileStatus: TokenLevelTokenScriptDisplayStatus? {
        didSet {
            for each in tokenScriptFileStatusStackView.subviews {
                each.removeFromSuperview()
            }
            tokenScriptFileStatusStackView.isHidden = true
            guard let tokenScriptFileStatus = tokenScriptFileStatus else { return }
            switch tokenScriptFileStatus {
            case .type0NoTokenScript:
                return
            case .type1GoodTokenScriptSignatureGoodOrOptional, .type2BadTokenScript:
                let button = createTokenScriptFileStatusButton(withStatus: tokenScriptFileStatus, urlOpener: self)
                tokenScriptFileStatusStackView.addArrangedSubviews([.spacerWidth(7), button, .spacerWidth(1, flexible: true)])
                tokenScriptFileStatusStackView.isHidden = false
            }
        }
    }
    weak var delegate: TokenViewControllerHeaderViewDelegate?

    init(contract: AlphaWallet.Address) {
        self.contract = contract
        super.init(frame: .zero)

        sendHeaderView.delegate = self

        let stackView = [
            .spacer(height: 30),
            tokenScriptFileStatusStackView,
            sendHeaderView,
            recentTransactionsLabel,
            .spacer(height: 14),
            border,
            .spacer(height: 7),
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            border.heightAnchor.constraint(equalToConstant: 1),

            stackView.anchorsConstraint(to: self, edgeInsets: .init(top: 0, left: 30, bottom: 0, right: 30)),
        ])

        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        recentTransactionsLabel.textColor = UIColor(red: 77, green: 77, blue: 77)
        recentTransactionsLabel.font = Fonts.semibold(size: 18)
        recentTransactionsLabel.text = R.string.localizable.recentTransactions()

        border.backgroundColor = UIColor(red: 236, green: 236, blue: 236)
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
