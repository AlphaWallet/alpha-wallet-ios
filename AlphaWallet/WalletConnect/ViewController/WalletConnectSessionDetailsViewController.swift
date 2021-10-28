//
//  SessionDetailsViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.07.2020.
//

import UIKit 
import Kingfisher

protocol WalletConnectSessionViewControllerDelegate: AnyObject {
    func controller(_ controller: WalletConnectSessionViewController, disconnectSelected sender: UIButton)
    func didDismiss(in controller: WalletConnectSessionViewController)
}

class WalletConnectSessionViewController: UIViewController {

    private let viewModel: WalletConnectSessionDetailsViewModel
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        return imageView
    }()
    private let iconTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    private let statusRow = WalletConnectRowView()
    private let nameRow = WalletConnectRowView()
    private let connectedToRow = WalletConnectRowView()
    private let chainRow = WalletConnectRowView()
    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))

    weak var delegate: WalletConnectSessionViewControllerDelegate?

    init(viewModel: WalletConnectSessionDetailsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        let imageContainerView: UIView = {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false

            let stackView = [imageView, iconTitleLabel].asStackView(axis: .vertical, alignment: .center)
            stackView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(stackView)

            NSLayoutConstraint.activate([
                imageView.heightAnchor.constraint(equalToConstant: 40),
                imageView.widthAnchor.constraint(equalToConstant: 40),
                stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            ])

            return view
        }()

        let stackView = [
            imageContainerView,
            statusRow,
            nameRow,
            connectedToRow,
            chainRow,
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)
        view.backgroundColor = Colors.appBackground

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar)
        view.addSubview(footerBar)

        NSLayoutConstraint.activate([
            imageContainerView.heightAnchor.constraint(equalToConstant: 200),
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),

            footerBar.anchorsConstraint(to: view),
        ])

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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        imageView.layer.cornerRadius = imageView.bounds.height / 2
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
        imageView.setImage(url: viewModel.sessionIconURL, placeholder: viewModel.walletImageIcon)
        iconTitleLabel.attributedText = viewModel.nameAttributedString

        let button0 = buttonsBar.buttons[0]
        button0.setTitle(viewModel.dissconnectButtonText, for: .normal)
        button0.addTarget(self, action: #selector(disconnectButtonSelected), for: .touchUpInside)
        button0.isEnabled = viewModel.isDisconnectAvailable
    }

    @objc private func disconnectButtonSelected(_ sender: UIButton) {
        delegate?.controller(self, disconnectSelected: sender)
    }
}

extension UIImageView {

    func setImage(url urlValue: URL?, placeholder: UIImage? = .none) {
        if let url = urlValue {
            let resource = ImageResource(downloadURL: url)
            var options: KingfisherOptionsInfo = []

            if let value = placeholder {
                options.append(.onFailureImage(value))
            }

            kf.setImage(with: resource, placeholder: placeholder, options: options)
        } else {
            image = placeholder
        }
    }
}
