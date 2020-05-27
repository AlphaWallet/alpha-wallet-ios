// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Alamofire

protocol ImportMagicTokenViewControllerDelegate: class, CanOpenURL {
    func didPressDone(in viewController: ImportMagicTokenViewController)
    func didPressImport(in viewController: ImportMagicTokenViewController)
}

class ImportMagicTokenViewController: UIViewController, OptionalTokenVerifiableStatusViewController {
    enum State {
        case ready(ImportMagicTokenViewControllerViewModel)
        case notReady
    }

    private let roundedBackground = RoundedBackground()
    private let header = TokensCardViewControllerTitleHeader()
    lazy private var tokenCardRowView = TokenCardRowView(server: server, tokenView: .viewIconified, assetDefinitionStore: assetDefinitionStore)
    private let statusLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .whiteLarge)
    private var costStackView: UIStackView?
    private let ethCostLabelLabel = UILabel()
    private let ethCostLabel = UILabel()
    private let dollarCostLabelLabel = UILabel()
    private let dollarCostLabel = PaddedLabel()
    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 2))
    private var viewModel: ImportMagicTokenViewControllerViewModel?

    let server: RPCServer
    let assetDefinitionStore: AssetDefinitionStore
    weak var delegate: ImportMagicTokenViewControllerDelegate?

    var contract: AlphaWallet.Address? {
        didSet {
            guard url != nil else { return }
            updateNavigationRightBarButtons(withTokenScriptFileStatus: tokenScriptFileStatus, hasShowInfoButton: false)
        }
    }
    var url: URL? {
        didSet {
            updateNavigationRightBarButtons(withTokenScriptFileStatus: nil, hasShowInfoButton: false)
        }
    }
    var state: State {
        if let viewModel = viewModel {
            return .ready(viewModel)
        } else {
            return .notReady
        }
    }

    init(server: RPCServer, assetDefinitionStore: AssetDefinitionStore) {
        self.server = server
        self.assetDefinitionStore = assetDefinitionStore
        super.init(nibName: nil, bundle: nil)

        view.backgroundColor = .clear

        tokenCardRowView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tokenCardRowView)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        ethCostLabelLabel.translatesAutoresizingMaskIntoConstraints = false
        ethCostLabel.translatesAutoresizingMaskIntoConstraints = false
        dollarCostLabelLabel.translatesAutoresizingMaskIntoConstraints = false
        dollarCostLabel.translatesAutoresizingMaskIntoConstraints = false

        let separator1 = UIView()
        separator1.backgroundColor = UIColor(red: 230, green: 230, blue: 230)

        let separator2 = UIView()
        separator2.backgroundColor = UIColor(red: 230, green: 230, blue: 230)

        costStackView = [
            ethCostLabelLabel,
            .spacer(height: 7),
            separator1,
            .spacer(height: 7),
            ethCostLabel,
            .spacer(height: 7),
            separator2,
            .spacer(height: 7),
            dollarCostLabelLabel,
            .spacer(height: 3),
            dollarCostLabel,
        ].asStackView(axis: .vertical, alignment: .center)
        costStackView?.translatesAutoresizingMaskIntoConstraints = false

        let stackView = [
            header,
            .spacer(height: 1),
            tokenCardRowView,
            .spacer(height: 1),
            activityIndicator,
            .spacer(height: 14),
            statusLabel,
            .spacer(height: 20),
            costStackView!,
        ].asStackView(axis: .vertical, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(stackView)

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = .clear
        roundedBackground.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)

        NSLayoutConstraint.activate([
            header.heightAnchor.constraint(equalToConstant: 90),

            tokenCardRowView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tokenCardRowView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            separator1.heightAnchor.constraint(equalToConstant: 1),
            separator1.leadingAnchor.constraint(equalTo: tokenCardRowView.background.leadingAnchor),
            separator1.trailingAnchor.constraint(equalTo: tokenCardRowView.background.trailingAnchor),

            separator2.heightAnchor.constraint(equalToConstant: 1),
            separator2.leadingAnchor.constraint(equalTo: tokenCardRowView.background.leadingAnchor),
            separator2.trailingAnchor.constraint(equalTo: tokenCardRowView.background.trailingAnchor),

            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.topAnchor.constraint(equalTo: view.layoutGuide.bottomAnchor, constant: -ButtonsBar.buttonsHeight - ButtonsBar.marginAtBottomScreen),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            statusLabel.widthAnchor.constraint(equalTo: tokenCardRowView.widthAnchor, constant: -20),

            stackView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: ImportMagicTokenViewControllerViewModel) {
        self.viewModel = viewModel
        if let viewModel = self.viewModel {
            view.backgroundColor = viewModel.backgroundColor

            header.configure(title: viewModel.headerTitle)

            tokenCardRowView.configure(viewModel: ImportMagicTokenCardRowViewModel(importMagicTokenViewControllerViewModel: viewModel, assetDefinitionStore: assetDefinitionStore))

            tokenCardRowView.isHidden = !viewModel.showTokenRow
            tokenCardRowView.stateLabel.isHidden = true

            statusLabel.textColor = viewModel.statusColor
            statusLabel.font = viewModel.statusFont
            statusLabel.textAlignment = .center
            statusLabel.text = viewModel.statusText
            statusLabel.numberOfLines = 0

            costStackView?.isHidden = !viewModel.showCost

            ethCostLabelLabel.textColor = viewModel.ethCostLabelLabelColor
            ethCostLabelLabel.font = viewModel.ethCostLabelLabelFont
            ethCostLabelLabel.textAlignment = .center
            ethCostLabelLabel.text = viewModel.ethCostLabelLabelText

            ethCostLabel.textColor = viewModel.ethCostLabelColor
            ethCostLabel.font = viewModel.ethCostLabelFont
            ethCostLabel.textAlignment = .center
            ethCostLabel.text = viewModel.ethCostLabelText

            dollarCostLabelLabel.textColor = viewModel.dollarCostLabelLabelColor
            dollarCostLabelLabel.font = viewModel.dollarCostLabelLabelFont
            dollarCostLabelLabel.textAlignment = .center
            dollarCostLabelLabel.text = viewModel.dollarCostLabelLabelText
            dollarCostLabelLabel.isHidden = viewModel.hideDollarCost

            dollarCostLabel.textColor = viewModel.dollarCostLabelColor
            dollarCostLabel.font = viewModel.dollarCostLabelFont
            dollarCostLabel.textAlignment = .center
            dollarCostLabel.text = viewModel.dollarCostLabelText
            dollarCostLabel.backgroundColor = viewModel.dollarCostLabelBackgroundColor
            dollarCostLabel.layer.masksToBounds = true
            dollarCostLabel.isHidden = viewModel.hideDollarCost

            activityIndicator.color = viewModel.activityIndicatorColor

            if viewModel.showActivityIndicator {
                activityIndicator.startAnimating()
            } else {
                activityIndicator.stopAnimating()
            }

            buttonsBar.configure()

            let actionButton = buttonsBar.buttons[0]
            actionButton.setTitle(viewModel.actionButtonTitle, for: .normal)
            actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)

            let cancelButton = buttonsBar.buttons[1]
            cancelButton.setTitle(viewModel.cancelButtonTitle, for: .normal)
            cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)

            actionButton.isHidden = !viewModel.showActionButton

            updateNavigationRightBarButtons(withTokenScriptFileStatus: tokenScriptFileStatus, hasShowInfoButton: false)
        }
    }

    @objc func actionTapped() {
        delegate?.didPressImport(in: self)
    }

    @objc func cancel() {
        if let delegate = delegate {
            delegate.didPressDone(in: self)
        } else {
            dismiss(animated: true)
        }
    }
}

extension ImportMagicTokenViewController: VerifiableStatusViewController {
    func showContractWebPage() {
        guard let url = url else { return }
        delegate?.didPressViewContractWebPage(url, in: self)
    }

    //Just for protocol conformance. Do nothing
    func showInfo() {
    }

    func open(url: URL) {
        delegate?.didPressViewContractWebPage(url, in: self)
    }
}
