// Copyright © 2019 Stormbird PTE. LTD.

import UIKit

protocol CreateInitialWalletViewControllerDelegate: class {
    func didTapCreateWallet(inViewController viewController: CreateInitialWalletViewController)
    func didTapWatchWallet(inViewController viewController: CreateInitialWalletViewController)
    func didTapImportWallet(inViewController viewController: CreateInitialWalletViewController)
}

class CreateInitialWalletViewController: UIViewController {
    private let keystore: Keystore
    private var viewModel = CreateInitialViewModel()
    private let analyticsCoordinator: AnalyticsCoordinator
    private let roundedBackground = RoundedBackground()
    private let subtitleLabel = UILabel()
    private let imageView = UIImageView()
    private let createWalletButtonBar = ButtonsBar(configuration: .green(buttons: 1))
    private let separator = UIView.spacer(height: 1)
    private let haveWalletLabel = UILabel()
    private let buttonsBar = ButtonsBar(configuration: .white(buttons: 2))

    private var imageViewDimension: CGFloat {
        if ScreenChecker().isNarrowScreen {
            return 60
        } else {
            return 90
        }
    }
    private var topMarginOfImageView: CGFloat {
        if ScreenChecker().isNarrowScreen {
            return 100
        } else {
            return 170
        }
    }

    weak var delegate: CreateInitialWalletViewControllerDelegate?

    init(keystore: Keystore, analyticsCoordinator: AnalyticsCoordinator) {
        self.keystore = keystore
        self.analyticsCoordinator = analyticsCoordinator
        super.init(nibName: nil, bundle: nil)

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        imageView.contentMode = .scaleAspectFit

        let stackView = [
            UIView.spacer(height: topMarginOfImageView),
            imageView,
            UIView.spacer(height: 10),
            subtitleLabel,
            UIView.spacerWidth(flexible: true),
            createWalletButtonBar,
            UIView.spacer(height: 25),
            separator,
            UIView.spacer(height: 25),
            haveWalletLabel,
            UIView.spacer(height: 15),
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(stackView)

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
            stackView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            createWalletButtonBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),

            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -ButtonsBar.buttonsHeight - ButtonsBar.marginAtBottomScreen),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            roundedBackground.createConstraintsWithContainer(view: view),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        view.backgroundColor = Colors.appBackground

        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = viewModel.subtitleColor
        subtitleLabel.font = viewModel.subtitleFont
        subtitleLabel.text = viewModel.subtitle

        imageView.image = viewModel.imageViewImage

        separator.backgroundColor = viewModel.separatorColor

        haveWalletLabel.textAlignment = .center
        haveWalletLabel.textColor = viewModel.alreadyHaveWalletTextColor
        haveWalletLabel.font = viewModel.alreadyHaveWalletTextFont
        haveWalletLabel.text = viewModel.alreadyHaveWalletText

        createWalletButtonBar.configure()
        let createWalletButton = createWalletButtonBar.buttons[0]
        createWalletButton.setTitle(viewModel.createButtonTitle, for: .normal)
        createWalletButton.addTarget(self, action: #selector(createWallet), for: .touchUpInside)

        buttonsBar.configure()
        let watchButton = buttonsBar.buttons[0]
        watchButton.setTitle(viewModel.watchButtonTitle, for: .normal)
        watchButton.addTarget(self, action: #selector(watchWallet), for: .touchUpInside)
        let importButton = buttonsBar.buttons[1]
        importButton.setTitle(viewModel.importButtonTitle, for: .normal)
        importButton.addTarget(self, action: #selector(importWallet), for: .touchUpInside)
    }

    @objc private func createWallet() {
        delegate?.didTapCreateWallet(inViewController: self)
    }

    @objc private func watchWallet() {
        delegate?.didTapWatchWallet(inViewController: self)
    }

    @objc private func importWallet() {
        delegate?.didTapImportWallet(inViewController: self)
    }
}
