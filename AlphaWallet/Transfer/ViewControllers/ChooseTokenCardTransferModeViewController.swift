// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

protocol ChooseTokenCardTransferModeViewControllerDelegate: AnyObject, CanOpenURL {
    func didChooseTransferViaMagicLink(token: Token, tokenHolder: TokenHolder, in viewController: ChooseTokenCardTransferModeViewController)
    func didChooseTransferNow(token: Token, tokenHolder: TokenHolder, in viewController: ChooseTokenCardTransferModeViewController)
    func didPressViewInfo(in viewController: ChooseTokenCardTransferModeViewController)
}

class ChooseTokenCardTransferModeViewController: UIViewController, TokenVerifiableStatusViewController {
    private let tokenRowView: TokenRowView & UIView
    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 2))
    private var viewModel: ChooseTokenCardTransferModeViewModel
    private let analytics: AnalyticsLogger
    private let tokenHolder: TokenHolder
    private let containerView = ScrollableStackView()

    var contract: AlphaWallet.Address {
        return viewModel.token.contractAddress
    }
    var server: RPCServer {
        return viewModel.token.server
    }
    let assetDefinitionStore: AssetDefinitionStore
    let paymentFlow: PaymentFlow
    weak var delegate: ChooseTokenCardTransferModeViewControllerDelegate?

    init(
        analytics: AnalyticsLogger,
        tokenHolder: TokenHolder,
        paymentFlow: PaymentFlow,
        viewModel: ChooseTokenCardTransferModeViewModel,
        assetDefinitionStore: AssetDefinitionStore,
        keystore: Keystore,
        session: WalletSession
    ) {
        self.analytics = analytics
        self.tokenHolder = tokenHolder
        self.paymentFlow = paymentFlow
        self.viewModel = viewModel
        self.assetDefinitionStore = assetDefinitionStore

        let tokenType = OpenSeaBackedNonFungibleTokenHandling(token: viewModel.token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified)
        switch tokenType {
        case .backedByOpenSea:
            tokenRowView = OpenSeaNonFungibleTokenCardRowView(tokenView: .viewIconified)
        case .notBackedByOpenSea:
            tokenRowView = TokenCardRowView(analytics: analytics, server: viewModel.token.server, tokenView: .viewIconified, assetDefinitionStore: assetDefinitionStore, keystore: keystore, wallet: session.account)
        }

        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(withTokenScriptFileStatus: nil)

        tokenRowView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        containerView.stackView.addArrangedSubviews([
            .spacer(height: 18),
            tokenRowView,
        ])

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0.0)
        view.addSubview(containerView)
        view.addSubview(footerBar)

        let xOffset: CGFloat = 16

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: xOffset),
            containerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -xOffset),
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            footerBar.anchorsConstraint(to: view),
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        buttonsBar.configure()

        let generateMagicLinkButton = buttonsBar.buttons[0]
        generateMagicLinkButton.setTitle(R.string.localizable.aWalletTokenTransferModeMagicLinkButtonTitle(), for: .normal)
        generateMagicLinkButton.addTarget(self, action: #selector(generateMagicLinkTapped), for: .touchUpInside)

        let transferNowButton = buttonsBar.buttons[1]
        transferNowButton.setTitle(R.string.localizable.aWalletTokenTransferModeNowButtonTitle(), for: .normal)
        transferNowButton.addTarget(self, action: #selector(transferNowTapped), for: .touchUpInside)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func generateMagicLinkTapped() {
        delegate?.didChooseTransferViaMagicLink(token: viewModel.token, tokenHolder: tokenHolder, in: self)
    }

    @objc private func transferNowTapped() {
        delegate?.didChooseTransferNow(token: viewModel.token, tokenHolder: tokenHolder, in: self)
    }

    func configure(viewModel newViewModel: ChooseTokenCardTransferModeViewModel? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }
        updateNavigationRightBarButtons(withTokenScriptFileStatus: tokenScriptFileStatus)

        navigationItem.title = viewModel.headerTitle

        tokenRowView.configure(tokenHolder: tokenHolder)

        tokenRowView.stateLabel.isHidden = true
    }
}

extension ChooseTokenCardTransferModeViewController: VerifiableStatusViewController {
    func showInfo() {
        delegate?.didPressViewInfo(in: self)
    }

    func showContractWebPage() {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: self)
    }

    func open(url: URL) {
        delegate?.didPressViewContractWebPage(url, in: self)
    }
}
