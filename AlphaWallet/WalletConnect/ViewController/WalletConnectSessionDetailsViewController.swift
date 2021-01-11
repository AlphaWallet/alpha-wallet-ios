//
//  SessionDetailsViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.07.2020.
//

import UIKit
import WalletConnectSwift

protocol WalletConnectSessionViewControllerDelegate: class {
    func controller(_ controller: WalletConnectSessionViewController, disconnectSelected sender: UIButton)
    func didDismiss(in controller: WalletConnectSessionViewController)
}

class WalletConnectSessionViewController: UIViewController {

    private let viewModel: WalletConnectSessionDetailsViewModel
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    private let statusRow = WalletConnectRowView()
    private let nameRow = WalletConnectRowView()
    private let connectedToRow = WalletConnectRowView()
    private let chainRow = WalletConnectRowView()
    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))
    private let roundedBackground = RoundedBackground()
    private let separatorList: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.mercury()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    weak var delegate: WalletConnectSessionViewControllerDelegate?

    init(viewModel: WalletConnectSessionDetailsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        let stackView = [
            [.spacerWidth(50), imageView, .spacerWidth(50)].asStackView(),
            statusRow,
            nameRow,
            connectedToRow,
            chainRow,
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
            separatorList.heightAnchor.constraint(equalToConstant: 1),
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
        delegate?.didDismiss(in: self)
    }

    private func configure(viewModel: WalletConnectSessionDetailsViewModel) {
        title = viewModel.navigationTitle

        statusRow.configure(viewModel: viewModel.statusRowViewModel)
        nameRow.configure(viewModel: viewModel.nameRowViewModel)
        connectedToRow.configure(viewModel: viewModel.connectedToRowViewModel)
        chainRow.configure(viewModel: viewModel.chainRowViewModel)
        imageView.image = viewModel.walletImageIcon

        let button0 = buttonsBar.buttons[0]
        button0.setTitle(viewModel.dissconnectButtonText, for: .normal)
        button0.addTarget(self, action: #selector(disconnectButtonSelected), for: .touchUpInside)
        button0.isEnabled = viewModel.isDisconnectAvailable
    }

    @objc private func disconnectButtonSelected(_ sender: UIButton) {
        delegate?.controller(self, disconnectSelected: sender)
    }
}
