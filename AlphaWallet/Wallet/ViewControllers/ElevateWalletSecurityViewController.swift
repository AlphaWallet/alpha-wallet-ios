// Copyright © 2019 Stormbird PTE. LTD.

import UIKit

protocol ElevateWalletSecurityViewControllerDelegate: class {
    func didTapLock(inViewController viewController: ElevateWalletSecurityViewController)
    func didCancelLock(inViewController viewController: ElevateWalletSecurityViewController)
}

class ElevateWalletSecurityViewController: UIViewController {
    private let keystore: Keystore
    private let account: EthereumAccount
    lazy private var viewModel = ElevateWalletSecurityViewModel(isHdWallet: keystore.isHdWallet(account: account))
    private let roundedBackground = RoundedBackground()
    private let subtitleLabel = UILabel()
    private let imageView = UIImageView()
    private let descriptionLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))

    private var imageViewDimension: CGFloat {
        if ScreenChecker().isNarrowScreen {
            return 180
        } else {
            return 250
        }
    }

    weak var delegate: ElevateWalletSecurityViewControllerDelegate?

    init(keystore: Keystore, account: EthereumAccount) {
        self.keystore = keystore
        self.account = account
        super.init(nibName: nil, bundle: nil)

        hidesBottomBarWhenPushed = true

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        imageView.contentMode = .scaleAspectFit

        let stackView = [
            UIView.spacer(height: ScreenChecker().isNarrowScreen ? 15 : 30),
            subtitleLabel,
            UIView.spacer(height: ScreenChecker().isNarrowScreen ? 15 : 40),
            imageView,
            UIView.spacer(height: ScreenChecker().isNarrowScreen ? 15 : 40),
            descriptionLabel,
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(stackView)

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(cancelButton)

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = .clear
        roundedBackground.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)

        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: imageViewDimension),

            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),

            cancelButton.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor, constant: 10),
            cancelButton.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor, constant: -10),
            cancelButton.bottomAnchor.constraint(equalTo: footerBar.topAnchor, constant: -20),

            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.topAnchor.constraint(equalTo: view.layoutGuide.bottomAnchor, constant: -ButtonsBar.buttonsHeight - ButtonsBar.marginAtBottomScreen),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        view.backgroundColor = Colors.appBackground

        title = viewModel.title

        subtitleLabel.numberOfLines = 0
        subtitleLabel.attributedText = viewModel.attributedSubtitle

        imageView.image = viewModel.imageViewImage

        descriptionLabel.numberOfLines = 0
        descriptionLabel.attributedText = viewModel.attributedDescription

        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        cancelButton.setTitle(R.string.localizable.skip(), for: .normal)
        cancelButton.titleLabel?.font = viewModel.cancelLockingButtonFont
        cancelButton.titleLabel?.adjustsFontSizeToFitWidth = true
        cancelButton.setTitleColor(viewModel.cancelLockingButtonTitleColor, for: .normal)

        buttonsBar.configure()
        let exportButton = buttonsBar.buttons[0]
        exportButton.setTitle(viewModel.title, for: .normal)
        exportButton.addTarget(self, action: #selector(tappedLockButton), for: .touchUpInside)
    }

    @objc private func tappedLockButton() {
        delegate?.didTapLock(inViewController: self)
    }

    @objc func cancel() {
        delegate?.didCancelLock(inViewController: self)
    }
}
