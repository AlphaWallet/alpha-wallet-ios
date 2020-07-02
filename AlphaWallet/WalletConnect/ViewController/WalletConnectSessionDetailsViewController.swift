//
//  SessionDetailsViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.07.2020.
//

import UIKit
import WalletConnectSwift

protocol WalletConnectSessionViewControllerDelegate: class {
    func controller(_ controller: WalletConnectSessionViewController, dissconnectSelected sender: UIButton)
    func signedTransactionSelected(in controller: WalletConnectSessionViewController)
    func didDissmiss(in controller: WalletConnectSessionViewController)
}

class WalletConnectSessionViewController: UIViewController {

    private let viewModel: WalletConnectSessionDetailsViewModel
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    private let statusRow = WallerConnectRawView()
    private let nameRow = WallerConnectRawView()
    private let connectedToRow = WallerConnectRawView()
    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))
    private let roundedBackground = RoundedBackground()
    private let separatorList: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.mercury()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let transactionsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .left
        label.text = R.string.localizable.walletConnectSessionSignedTransactions()
        label.font = Fonts.regular(size: 17)
        label.textColor = Colors.black
        label.isUserInteractionEnabled = true

        return label
    }()

    private let transactionsDisclosureImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.image = R.image.chevronRight()?.withRenderingMode(.alwaysTemplate)
        imageView.tintColor = R.color.mercury()
        return imageView
    }()

    weak var delegate: WalletConnectSessionViewControllerDelegate?
    
    init(viewModel: WalletConnectSessionDetailsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        
        let tap = UIGestureRecognizer(target: self, action: #selector(signedTransactionSelected))
        transactionsLabel.addGestureRecognizer(tap)

        let transactionsLabelStackView = [
            .spacerWidth(16),
            transactionsLabel,
            transactionsDisclosureImageView,
            .spacerWidth(16)
        ].asStackView()

        let stackView = [
            [.spacerWidth(50), imageView, .spacerWidth(50)].asStackView(),
            statusRow,
            nameRow,
            connectedToRow,
            transactionsLabelStackView,
            separatorList
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        roundedBackground.addSubview(stackView)

        view.backgroundColor = Colors.appBackground

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar)
        roundedBackground.addSubview(footerBar)

        NSLayoutConstraint.activate([
            transactionsDisclosureImageView.heightAnchor.constraint(equalToConstant: 20),
            transactionsDisclosureImageView.widthAnchor.constraint(equalToConstant: 20),

            separatorList.heightAnchor.constraint(equalToConstant: 1),
            transactionsLabelStackView.heightAnchor.constraint(equalToConstant: 60),
            imageView.heightAnchor.constraint(equalToConstant: 250),
            stackView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),

            footerBar.anchorsConstraint(to: view),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
        
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        buttonsBar.configure()
        reload()
        
        hidesBottomBarWhenPushed = true
        navigationItem.hidesBackButton = true
        navigationItem.leftBarButtonItem = UIBarButtonItem.backBarButton(self, selector: #selector(backButtonSelected))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationItem.largeTitleDisplayMode = .never
    }

    func reload() {
        configure(viewModel: viewModel)
    }

    @objc private func backButtonSelected(_ sender: UIBarButtonItem) {
        delegate?.didDissmiss(in: self)
    }

    private func configure(viewModel: WalletConnectSessionDetailsViewModel) {
        title = viewModel.navigationTitle

        statusRow.configure(viewModel: viewModel.statusRowViewModel)
        nameRow.configure(viewModel: viewModel.nameRowViewModel)
        connectedToRow.configure(viewModel: viewModel.connectedToRowViewModel)
        imageView.image = viewModel.walletImageIcon

        let button0 = buttonsBar.buttons[0]
        button0.setTitle(viewModel.dissconnectButtonText, for: .normal)
        button0.addTarget(self, action: #selector(dissconnectButtonSelected), for: .touchUpInside)
        button0.isEnabled = viewModel.isDisconnectAvailable
    }

    @objc private func signedTransactionSelected(_ sender: UITapGestureRecognizer) {
        delegate?.signedTransactionSelected(in: self)
    }

    @objc private func dissconnectButtonSelected(_ sender: UIButton) {
        delegate?.controller(self, dissconnectSelected: sender)
    }
}
