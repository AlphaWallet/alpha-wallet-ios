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
    func didClose(in controller: WalletConnectSessionViewController)
}

class WalletConnectSessionViewController: UIViewController {

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
            view.heightAnchor.constraint(equalToConstant: ScreenChecker.size(big: 200, medium: 200, small: 150))
        ])

        return view
    }()

    private let statusRow = WalletConnectRowView()
    private let dappNameRow = WalletConnectRowView()
    private let dappUrlRow = WalletConnectRowView()
    private let chainRow = WalletConnectRowView()
    private let methodsRow = WalletConnectRowView()
    private let buttonsBar: HorizontalButtonsBar = {
        let buttonsBar = HorizontalButtonsBar(configuration: .combined(buttons: 2))
        buttonsBar.configure()
        return buttonsBar
    }()
    private lazy var containerView: ScrollableStackView = {
        let view = ScrollableStackView()
        return view
    }()
    private var cancelable = Set<AnyCancellable>()
    private var disconnectButton: UIButton { buttonsBar.buttons[0] }
    private var changeNetworksButton: UIButton { buttonsBar.buttons[0] }

    let viewModel: WalletConnectSessionDetailsViewModel
    weak var delegate: WalletConnectSessionViewControllerDelegate?

    init(viewModel: WalletConnectSessionDetailsViewModel) {
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)

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

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0)
        view.addSubview(footerBar)
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            footerBar.anchorsConstraint(to: view),
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        hidesBottomBarWhenPushed = true
        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        changeNetworksButton.addTarget(self, action: #selector(switchNetworkButtonSelected), for: .touchUpInside)

        bind(viewModel: viewModel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationItem.largeTitleDisplayMode = .never
    }

    private func bind(viewModel: WalletConnectSessionDetailsViewModel) {
        let disconnect = buttonsBar.buttons[0].publisher(forEvent: .touchUpInside).eraseToAnyPublisher()

        let input = WalletConnectSessionDetailsViewModelInput(disconnect: disconnect)
        let output = viewModel.transform(input: input)

        output.viewState
            .sink { [weak self] viewState in
                self?.navigationItem.title = viewState.title
                self?.statusRow.configure(viewModel: viewState.statusRowViewModel)
                self?.dappNameRow.configure(viewModel: viewState.dappNameRowViewModel)
                self?.dappUrlRow.configure(viewModel: viewState.dappUrlRowViewModel)
                self?.chainRow.configure(viewModel: viewState.chainRowViewModel)
                self?.methodsRow.configure(viewModel: viewState.methodsRowViewModel)
                self?.imageView.setImage(url: viewState.sessionIconURL, placeholder: viewState.walletImageIcon)
                self?.iconTitleLabel.attributedText = viewState.dappNameAttributedString

                self?.disconnectButton.isEnabled = viewState.isDisconnectEnabled
                self?.disconnectButton.setTitle(viewState.dissconnectButtonText, for: .normal)

                self?.changeNetworksButton.setTitle(viewState.changeNetworksButtonText, for: .normal)
                self?.changeNetworksButton.isEnabled = viewState.isSwitchServerEnabled
            }.store(in: &cancelable)

        output.didDisconnect
            .compactMap { _ in self.navigationController }
            .sink { $0.popViewController(animated: true) }
            .store(in: &cancelable)
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
