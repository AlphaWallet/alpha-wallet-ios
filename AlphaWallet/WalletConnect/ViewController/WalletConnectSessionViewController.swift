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

    let viewModel: WalletConnectSessionDetailsViewModel
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
    private lazy var containerView: ScrollableStackView = {
        let view = ScrollableStackView()
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

        view.stackView.addArrangedSubviews(subviews)

        return view
    }()
    private var cancelable = Set<AnyCancellable>()

    weak var delegate: WalletConnectSessionViewControllerDelegate?

    init(viewModel: WalletConnectSessionDetailsViewModel) {
        self.viewModel = viewModel

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
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        buttonsBar.configure(.combined(buttons: 2))

        let button0 = buttonsBar.buttons[0]
        button0.setTitle(viewModel.dissconnectButtonText, for: .normal)

        let button1 = buttonsBar.buttons[1]
        button1.setTitle(viewModel.switchNetworkButtonText, for: .normal)
        button1.addTarget(self, action: #selector(switchNetworkButtonSelected), for: .touchUpInside)

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
            .sink { [navigationItem, statusRow, dappNameRow, dappUrlRow, chainRow, methodsRow, imageView, iconTitleLabel, buttonsBar] viewState in
                navigationItem.title = viewState.title
                statusRow.configure(viewModel: viewState.statusRowViewModel)
                dappNameRow.configure(viewModel: viewState.dappNameRowViewModel)
                dappUrlRow.configure(viewModel: viewState.dappUrlRowViewModel)
                chainRow.configure(viewModel: viewState.chainRowViewModel)
                methodsRow.configure(viewModel: viewState.methodsRowViewModel)
                imageView.setImage(url: viewState.sessionIconURL, placeholder: viewModel.walletImageIcon)
                iconTitleLabel.attributedText = viewState.dappNameAttributedString

                let button0 = buttonsBar.buttons[0]
                button0.isEnabled = viewState.isDisconnectEnabled

                let button1 = buttonsBar.buttons[1]
                button1.isEnabled = viewState.isSwitchServerEnabled

            }.store(in: &cancelable)

        output.close
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
