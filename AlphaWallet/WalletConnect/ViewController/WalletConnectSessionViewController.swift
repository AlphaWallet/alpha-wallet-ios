//
//  SessionDetailsViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.07.2020.
//

import UIKit
import Combine
import AlphaWalletFoundation

protocol WalletConnectSessionViewControllerDelegate: AnyObject {
    func controller(_ controller: WalletConnectSessionViewController, switchNetworkSelected sender: UIButton)
    func controller(_ controller: WalletConnectSessionViewController, disconnectSelected sender: UIButton)
    func didClose(in controller: WalletConnectSessionViewController)
}

class WalletConnectSessionViewController: UIViewController {

    private var viewModel: WalletConnectSessionDetailsViewModel
    private let imageView: RoundedImageView = {
        let imageView = RoundedImageView(size: .init(width: 40, height: 40))
        return imageView
    }()
    private let iconTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    private lazy var imageContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false

        let stackView = [imageView, iconTitleLabel].asStackView(axis: .vertical, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            view.heightAnchor.constraint(equalToConstant: 200)
        ])

        return view
    }()

    private let statusRow = WalletConnectRowView()
    private let dappNameRow = WalletConnectRowView()
    private let dappUrlRow = WalletConnectRowView()
    private let chainRow = WalletConnectRowView()
    private let methodsRow = WalletConnectRowView()
    private let buttonsBar = HorizontalButtonsBar(configuration: .empty)
    var rpcServers: [RPCServer] {
        viewModel.rpcServers
    }

    weak var delegate: WalletConnectSessionViewControllerDelegate?
    private lazy var containerView: ScrollableStackView = {
        let view = ScrollableStackView()
        return view
    }()
    private let provider: WalletConnectServerProviderType
    private var cancelable = Set<AnyCancellable>()
    
    init(viewModel: WalletConnectSessionDetailsViewModel, provider: WalletConnectServerProviderType) {
        self.viewModel = viewModel
        self.provider = provider
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
        view.backgroundColor = Colors.appBackground

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0)
        view.addSubview(footerBar)
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            footerBar.anchorsConstraint(to: view),
        ])

        regenerateSubviews()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        buttonsBar.configure(.combined(buttons: 2))

        let button0 = buttonsBar.buttons[0]
        button0.setTitle(viewModel.dissconnectButtonText, for: .normal)
        button0.addTarget(self, action: #selector(disconnectButtonSelected), for: .touchUpInside)

        let button1 = buttonsBar.buttons[1]
        button1.setTitle(viewModel.switchNetworkButtonText, for: .normal)
        button1.addTarget(self, action: #selector(switchNetworkButtonSelected), for: .touchUpInside)

        reconfigure()
        
        provider.sessions
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reconfigure()
            }.store(in: &cancelable)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationItem.largeTitleDisplayMode = .never
    }

    private func regenerateSubviews() {
        containerView.stackView.removeAllArrangedSubviews()

        var subviews: [UIView] = [
            imageContainerView,
            statusRow,
            dappNameRow,
            dappUrlRow,
            chainRow
        ]
        if !viewModel.methods.isEmpty {
            subviews += [methodsRow]
        }
        
        containerView.stackView.addArrangedSubviews(subviews)
    }

    private func reconfigure() {
        guard let session = provider.session(for: viewModel.topicOrUrl) else {
            //NOTE: actually this case should newer happend
            return configure(viewModel: viewModel)
        }

        configure(viewModel: .init(provider: provider, session: session))
    }

    func configure(viewModel: WalletConnectSessionDetailsViewModel) {
        self.viewModel = viewModel

        title = viewModel.navigationTitle

        statusRow.configure(viewModel: viewModel.statusRowViewModel)
        dappNameRow.configure(viewModel: viewModel.dappNameRowViewModel)
        dappUrlRow.configure(viewModel: viewModel.dappUrlRowViewModel)
        chainRow.configure(viewModel: viewModel.chainRowViewModel)
        methodsRow.configure(viewModel: viewModel.methodsRowViewModel)
        imageView.setImage(url: viewModel.sessionIconURL, placeholder: viewModel.walletImageIcon)
        iconTitleLabel.attributedText = viewModel.dappNameAttributedString

        let button0 = buttonsBar.buttons[0]
        button0.isEnabled = viewModel.isDisconnectAvailable

        let button1 = buttonsBar.buttons[1]
        button1.isEnabled = viewModel.isSwitchServerEnabled
    }

    @objc private func disconnectButtonSelected(_ sender: UIButton) {
        delegate?.controller(self, disconnectSelected: sender)
    }

    @objc private func switchNetworkButtonSelected(_ sender: UIButton) {
        delegate?.controller(self, switchNetworkSelected: sender)
    }
}

extension WalletConnectSessionViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        delegate?.didClose(in: self)
    }
}
