// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

protocol ImportMagicTokenViewControllerDelegate: AnyObject, CanOpenURL {
    func didPressDone(in viewController: ImportMagicTokenViewController)
    func didPressImport(in viewController: ImportMagicTokenViewController)
}

class ImportMagicTokenViewController: UIViewController, OptionalTokenVerifiableStatusViewController {
    private lazy var tokenCardRowView = TokenCardRowView(server: session.server, tokenView: .viewIconified, assetDefinitionStore: assetDefinitionStore, wallet: session.account)
    private let statusLabel = UILabel()
    private let activityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true

        return activityIndicator
    }()
    private var costStackView: UIStackView!
    private let ethCostLabelLabel = UILabel()
    private let ethCostLabel = UILabel()
    private let dollarCostLabelLabel = UILabel()
    private let dollarCostLabel = PaddedLabel()
    private let buttonsBar = HorizontalButtonsBar(configuration: .custom(types: [.primary, .secondary]))
    private (set) var viewModel: ImportMagicTokenViewModel

    let assetDefinitionStore: AssetDefinitionStore
    weak var delegate: ImportMagicTokenViewControllerDelegate?

    var contract: AlphaWallet.Address? {
        didSet {
            guard url != nil else { return }
            updateNavigationRightBarButtons(withTokenScriptFileStatus: tokenScriptFileStatus, hasShowInfoButton: false)
        }
    }
    var server: RPCServer { session.server }
    var url: URL? {
        didSet { updateNavigationRightBarButtons(withTokenScriptFileStatus: nil, hasShowInfoButton: false) }
    }

    private let session: WalletSession
    private lazy var containerView: ScrollableStackView = {
        let containerView = ScrollableStackView()
        containerView.stackView.axis = .vertical
        containerView.stackView.alignment = .center

        return containerView
    }()

    init(assetDefinitionStore: AssetDefinitionStore,
         session: WalletSession,
         viewModel: ImportMagicTokenViewModel) {

        self.viewModel = viewModel
        self.assetDefinitionStore = assetDefinitionStore
        self.session = session

        super.init(nibName: nil, bundle: nil)

        tokenCardRowView.translatesAutoresizingMaskIntoConstraints = false
        ethCostLabelLabel.translatesAutoresizingMaskIntoConstraints = false
        ethCostLabel.translatesAutoresizingMaskIntoConstraints = false
        dollarCostLabelLabel.translatesAutoresizingMaskIntoConstraints = false
        dollarCostLabel.translatesAutoresizingMaskIntoConstraints = false

        let separator1 = UIView.separator()
        let separator2 = UIView.separator()

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
        costStackView.translatesAutoresizingMaskIntoConstraints = false

        containerView.stackView.addArrangedSubviews([
            tokenCardRowView,
            .spacer(height: 1),
            activityIndicator,
            .spacer(height: 14),
            statusLabel,
            .spacer(height: 20),
            costStackView!,
        ])

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0)
        view.addSubview(footerBar)
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            tokenCardRowView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tokenCardRowView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            separator1.leadingAnchor.constraint(equalTo: tokenCardRowView.background.leadingAnchor),
            separator1.trailingAnchor.constraint(equalTo: tokenCardRowView.background.trailingAnchor),

            separator2.leadingAnchor.constraint(equalTo: tokenCardRowView.background.leadingAnchor),
            separator2.trailingAnchor.constraint(equalTo: tokenCardRowView.background.trailingAnchor),

            statusLabel.widthAnchor.constraint(equalTo: tokenCardRowView.widthAnchor, constant: -20),

            containerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            footerBar.anchorsConstraint(to: view),
        ])
        configure(viewModel: viewModel)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: ImportMagicTokenViewModel) {
        self.viewModel = viewModel
        navigationItem.title = viewModel.headerTitle

        tokenCardRowView.configure(viewModel: ImportMagicTokenCardRowViewModel(viewModel: viewModel, assetDefinitionStore: assetDefinitionStore))

        tokenCardRowView.isHidden = !viewModel.showTokenRow
        tokenCardRowView.stateLabel.isHidden = true

        statusLabel.textColor = viewModel.statusColor
        statusLabel.font = viewModel.statusFont
        statusLabel.textAlignment = .center
        statusLabel.text = viewModel.statusText
        statusLabel.numberOfLines = 0

        costStackView.isHidden = !viewModel.showCost

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

    @objc private func actionTapped() {
        delegate?.didPressImport(in: self)
    }

    @objc private func cancel() {
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
