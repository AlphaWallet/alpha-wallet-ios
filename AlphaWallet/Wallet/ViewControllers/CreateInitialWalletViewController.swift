// Copyright © 2019 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

protocol CreateInitialWalletViewControllerDelegate: AnyObject {
    func didTapCreateWallet(inViewController viewController: CreateInitialWalletViewController)
    func didTapWatchWallet(inViewController viewController: CreateInitialWalletViewController)
    func didTapImportWallet(inViewController viewController: CreateInitialWalletViewController)
}

class CreateInitialWalletViewController: UIViewController {
    private let keystore: Keystore
    private var viewModel = CreateInitialViewModel()
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit

        return imageView
    }()
    private let buttonsBar = VerticalButtonsBar(numberOfButtons: 2)
    private lazy var titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        return titleLabel
    }()

    weak var delegate: CreateInitialWalletViewControllerDelegate?

    init(keystore: Keystore) {
        self.keystore = keystore
        super.init(nibName: nil, bundle: nil)

        view.addSubview(imageView)
        view.addSubview(titleLabel)

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0)
        view.addSubview(footerBar)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),

            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            footerBar.anchorsConstraint(to: view)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        imageView.image = viewModel.imageViewImage
        titleLabel.attributedText = viewModel.titleAttributedString

        let createWalletButton = buttonsBar.buttons[0]
        createWalletButton.setTitle(viewModel.createWalletButtonTitle, for: .normal)
        createWalletButton.addTarget(self, action: #selector(createWalletSelected), for: .touchUpInside)

        let alreadyHaveWalletButton = buttonsBar.buttons[1]
        alreadyHaveWalletButton.setTitle(viewModel.alreadyHaveWalletButtonText, for: .normal)
        alreadyHaveWalletButton.addTarget(self, action: #selector(alreadyHaveWalletWallet), for: .touchUpInside)
    }

    @objc private func createWalletSelected(_ sender: UIButton) {
        delegate?.didTapCreateWallet(inViewController: self)
    }

    @objc private func alreadyHaveWalletWallet(_ sender: UIButton) {
        let viewController = makeAlreadyHaveWalletAlertSheet(sender: sender)
        present(viewController, animated: true)
    }

    private func makeAlreadyHaveWalletAlertSheet(sender: UIView) -> UIAlertController {
        let alertController = UIAlertController(
            title: nil,
            message: nil,
            preferredStyle: .actionSheet)
        alertController.popoverPresentationController?.sourceView = sender
        alertController.popoverPresentationController?.sourceRect = sender.centerRect

        let importWalletAction = UIAlertAction(title: viewModel.importButtonTitle, style: .default) { _ in
            self.delegate?.didTapImportWallet(inViewController: self)
        }

        let trackWalletAction = UIAlertAction(title: viewModel.watchButtonTitle, style: .default) { _ in
            self.delegate?.didTapWatchWallet(inViewController: self)
        }

        let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in }

        alertController.addAction(importWalletAction)
        alertController.addAction(trackWalletAction)
        alertController.addAction(cancelAction)

        return alertController
    }
}
