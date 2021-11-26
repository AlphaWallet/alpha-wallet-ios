// Copyright © 2019 Stormbird PTE. LTD.

import UIKit

protocol CreateInitialWalletViewControllerDelegate: AnyObject {
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
    private let buttonsBar = ButtonsBar(configuration: .white(buttons: 2), showHaveWalletLabel: true)

    private var imageViewDimension: CGFloat {
        if ScreenChecker().isNarrowScreen {
            return 49
        } else {
            return 49
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
            UIView.spacer(height: 40),
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(stackView)

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)
        footerBar.backgroundColor = Colors.appWhite
        footerBar.layer.cornerRadius = 5
        footerBar.layer.shadowColor = UIColor.lightGray.cgColor
        footerBar.layer.shadowRadius = 2
        footerBar.layer.shadowOffset = .zero
        footerBar.layer.shadowOpacity = 0.6
        
        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: imageViewDimension),

            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            createWalletButtonBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),

            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonWithLabelHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            footerBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -(ButtonsBar.buttonWithLabelHeight + 20)),
            footerBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonWithLabelHeight + 20),
            roundedBackground.createConstraintsWithContainer(view: view),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    func configure() {
        view.backgroundColor = Colors.appBackground

        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = viewModel.subtitleColor
        subtitleLabel.font = viewModel.subtitleFont
        subtitleLabel.text = viewModel.subtitle

        imageView.image = viewModel.imageViewImage

        separator.backgroundColor = viewModel.separatorColor
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
