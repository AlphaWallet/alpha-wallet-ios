// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

protocol TransferTokenCardQuantitySelectionViewControllerDelegate: AnyObject, CanOpenURL {
    func didSelectQuantity(token: Token, tokenHolder: TokenHolder, in viewController: TransferTokensCardQuantitySelectionViewController)
    func didPressViewInfo(in viewController: TransferTokensCardQuantitySelectionViewController)
}

class TransferTokensCardQuantitySelectionViewController: UIViewController, TokenVerifiableStatusViewController {
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = Configuration.Color.Semantic.defaultForegroundText
        label.font = Fonts.regular(size: 10)

        return label
    }()

    private let quantityStepper: NumberStepper = {
        let quantityStepper = NumberStepper()
        quantityStepper.translatesAutoresizingMaskIntoConstraints = false
        quantityStepper.minimumValue = 1
        quantityStepper.value = 1

        return quantityStepper
    }()
    private let tokenRowView: TokenRowView & UIView
    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
    private (set) var viewModel: TransferTokensCardQuantitySelectionViewModel
    private let containerView = ScrollableStackView()

    var contract: AlphaWallet.Address {
        return viewModel.token.contractAddress
    }
    var server: RPCServer {
        return viewModel.token.server
    }
    let assetDefinitionStore: AssetDefinitionStore

    weak var delegate: TransferTokenCardQuantitySelectionViewControllerDelegate?

    init(viewModel: TransferTokensCardQuantitySelectionViewModel,
         assetDefinitionStore: AssetDefinitionStore) {

        self.viewModel = viewModel
        self.assetDefinitionStore = assetDefinitionStore

        let tokenType = OpenSeaBackedNonFungibleTokenHandling(token: viewModel.token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified)
        switch tokenType {
        case .backedByOpenSea:
            tokenRowView = OpenSeaNonFungibleTokenCardRowView(tokenView: .viewIconified)
        case .notBackedByOpenSea:
            tokenRowView = TokenCardRowView(server: viewModel.token.server, tokenView: .viewIconified, assetDefinitionStore: assetDefinitionStore, wallet: viewModel.session.account)
        }

        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(withTokenScriptFileStatus: nil)

        view.addSubview(containerView)

        containerView.stackView.addArrangedSubviews([
            .spacer(height: 18),
            tokenRowView,
            .spacer(height: 18),
            subtitleLabel,
            .spacer(height: 4),
            quantityStepper,
        ])

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0.0)
        view.addSubview(containerView)
        view.addSubview(footerBar)

        let xOffset: CGFloat = 16

        NSLayoutConstraint.activate([
            quantityStepper.heightAnchor.constraint(equalToConstant: 50),

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
        let nextButton = buttonsBar.buttons[0]
        nextButton.setTitle(R.string.localizable.aWalletNextButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func nextButtonTapped() {
        if quantityStepper.value == 0 {
            let tokenTypeName = assetDefinitionStore.xmlHandler(forTokenScriptSupportable: viewModel.token).getNameInPluralForm()
            UIAlertController.alert(title: "",
                                    message: R.string.localizable.aWalletTokenTransferSelectTokenQuantityAtLeastOneTitle(tokenTypeName),
                                    alertButtonTitles: [R.string.localizable.oK()],
                                    alertButtonStyles: [.cancel],
                                    viewController: self,
                                    completion: nil)
        } else {
            delegate?.didSelectQuantity(token: viewModel.token, tokenHolder: getTokenHolderFromQuantity(), in: self)
        }
    }

    func configure(viewModel newViewModel: TransferTokensCardQuantitySelectionViewModel? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }
        updateNavigationRightBarButtons(withTokenScriptFileStatus: tokenScriptFileStatus)

        navigationItem.title = viewModel.headerTitle
        subtitleLabel.text = viewModel.subtitleText
        tokenRowView.configure(tokenHolder: viewModel.tokenHolder)
        quantityStepper.maximumValue = viewModel.maxValue
        tokenRowView.stateLabel.isHidden = true
    }

    private func getTokenHolderFromQuantity() -> TokenHolder {
        let quantity = quantityStepper.value
        let tokenHolder = viewModel.tokenHolder
        let tokens = Array(tokenHolder.tokens[..<quantity])

        return TokenHolder(
            tokens: tokens,
            contractAddress: tokenHolder.contractAddress,
            hasAssetDefinition: tokenHolder.hasAssetDefinition)
    }
}

extension TransferTokensCardQuantitySelectionViewController: VerifiableStatusViewController {
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
