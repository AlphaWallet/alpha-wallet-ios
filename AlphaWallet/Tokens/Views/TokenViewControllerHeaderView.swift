// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol TokenViewControllerHeaderViewDelegate: class {
    func didPressViewContractWebPage(forContract contract: String, inHeaderView: TokenViewControllerHeaderView)
}

class TokenViewControllerHeaderView: UIView {
    enum VerificationStatus {
        case verified(String)
        case unverified
    }

    private let recentTransactionsLabel = UILabel()
    private let border = UIView()
    private let verifiedStackView = [].asStackView()
    private let unverifiedStackView = [].asStackView()
    private let verifiedButton = UIButton(type: .system)
    private let unverifiedButton = UIButton(type: .system)

    let sendHeaderView = SendHeaderView()
    var verificationStatus = VerificationStatus.unverified {
        didSet {
            switch verificationStatus {
            case .verified(let contract):
                verifiedStackView.isHidden = false
                unverifiedStackView.isHidden = true
            case .unverified:
                verifiedStackView.isHidden = true
                unverifiedStackView.isHidden = false
            }
        }
    }
    weak var delegate: TokenViewControllerHeaderViewDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)

        verifiedStackView.addArrangedSubviews([.spacerWidth(7), verifiedButton, .spacerWidth(1, flexible: true)])
        unverifiedStackView.addArrangedSubviews([.spacerWidth(7), unverifiedButton, .spacerWidth(1, flexible: true)])

        let stackView = [
            .spacer(height: 30),
            verifiedStackView,
            unverifiedStackView,
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

            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 30),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -30),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        verifiedButton.titleLabel?.font = Fonts.semibold(size: 12)
        verifiedButton.setTitleColor(Colors.appGreenContrastBackground, for: .normal)
        verifiedButton.setImage(R.image.verified()?.withRenderingMode(.alwaysOriginal), for: .normal)
        verifiedButton.setTitle(R.string.localizable.aWalletTokenVerifiedContract(), for: .normal)
        verifiedButton.imageEdgeInsets = .init(top: 0, left: 0, bottom: 0, right: 12)
        verifiedButton.titleEdgeInsets = .init(top: 0, left: 0, bottom: 0, right: -12)
        verifiedButton.addTarget(self, action: #selector(showContractWebPage), for: .touchUpInside)

        unverifiedButton.titleLabel?.font = Fonts.semibold(size: 12)
        unverifiedButton.setTitleColor(Colors.appRed, for: .normal)
        unverifiedButton.setImage(R.image.unverified()?.withRenderingMode(.alwaysOriginal), for: .normal)
        unverifiedButton.setTitle(R.string.localizable.aWalletTokenUnverifiedContract(), for: .normal)
        unverifiedButton.imageEdgeInsets = .init(top: 0, left: 0, bottom: 0, right: 12)
        unverifiedButton.titleEdgeInsets = .init(top: 0, left: 0, bottom: 0, right: -12)

        recentTransactionsLabel.textColor = UIColor(red: 77, green: 77, blue: 77)
        recentTransactionsLabel.font = Fonts.semibold(size: 18)
        recentTransactionsLabel.text = R.string.localizable.recentTransactions()

        border.backgroundColor = UIColor(red: 236, green: 236, blue: 236)
    }

    @objc private func showContractWebPage() {
        switch verificationStatus {
        case .verified(let contract):
            delegate?.didPressViewContractWebPage(forContract: contract, inHeaderView: self)
        case .unverified:
            break
        }
    }
}
