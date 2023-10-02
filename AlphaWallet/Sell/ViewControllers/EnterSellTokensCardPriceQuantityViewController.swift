// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import BigInt
import Combine
import AlphaWalletFoundation

protocol EnterSellTokensCardPriceQuantityViewControllerDelegate: AnyObject, CanOpenURL {
    func didEnterSellTokensPriceQuantity(token: Token, tokenHolder: TokenHolder, ethCost: Double, in viewController: EnterSellTokensCardPriceQuantityViewController)
    func didPressViewInfo(in viewController: EnterSellTokensCardPriceQuantityViewController)
}

class EnterSellTokensCardPriceQuantityViewController: UIViewController, TokenVerifiableStatusViewController {
    private let pricePerTokenLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .left
        label.textColor = Configuration.Color.Semantic.defaultForegroundText
        label.font = Fonts.regular(size: 10)

        return label
    }()
    private let quantityLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .left
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
    private let ethCostLabelLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = Configuration.Color.Semantic.defaultForegroundText
        label.font = Fonts.semibold(size: 21)

        return label
    }()
    private let ethCostLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = Configuration.Color.Semantic.defaultForegroundText
        label.font = Fonts.semibold(size: 21)

        return label
    }()
    private let dollarCostLabelLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = Configuration.Color.Semantic.defaultForegroundText
        label.font = Fonts.regular(size: 10)

        return label
    }()
    private let dollarCostLabel: PaddedLabel = {
        let label = PaddedLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = Configuration.Color.Semantic.alternativeText
        label.layer.masksToBounds = true
        label.font = Fonts.semibold(size: 21)

        return label
    }()

    private let tokenRowView: TokenRowView & UIView
    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
    private (set) var viewModel: EnterSellTokensCardPriceQuantityViewModel
    private var totalEthCost: Double {
        switch pricePerTokenField.cryptoValue {
        case .notSet:
            return .zero
        case .allFunds(let amount):
            return amount
        case .amount(let amount):
            return amount
        }
    }

    private var totalDollarCost: String {
        if let dollarCostPerToken = pricePerTokenField.fiatValue {
            let quantity = Double(quantityStepper.value)
            return StringFormatter().currency(with: dollarCostPerToken * quantity, currency: currencyService.currency)
        } else {
            return ""
        }
    }

    private let tokenImageFetcher: TokenImageFetcher
    private lazy var pricePerTokenField: AmountTextField = {
        let textField = AmountTextField(token: viewModel.ethToken, tokenImageFetcher: tokenImageFetcher)
        textField.selectCurrencyButton.isEnabled = false
        textField.selectCurrencyButton.hasToken = true
        textField.selectCurrencyButton.expandIconHidden = true
        textField.isAlternativeAmountEnabled = false
        textField.isAllFundsEnabled = false
        textField.inputAccessoryButtonType = .done

        return textField
    }()

    private var cancelable = Set<AnyCancellable>()
    private let service: TokensProcessingPipeline
    private let containerView: ScrollableStackView = {
        let containerView = ScrollableStackView()
        containerView.stackView.axis = .vertical
        containerView.stackView.alignment = .center

        return containerView
    }()
    private let currencyService: CurrencyService

    weak var delegate: EnterSellTokensCardPriceQuantityViewControllerDelegate?
    var contract: AlphaWallet.Address {
        return viewModel.token.contractAddress
    }
    var server: RPCServer {
        return viewModel.token.server
    }
    let assetDefinitionStore: AssetDefinitionStore

    init(viewModel: EnterSellTokensCardPriceQuantityViewModel,
         assetDefinitionStore: AssetDefinitionStore,
         service: TokensProcessingPipeline,
         currencyService: CurrencyService,
         tokenImageFetcher: TokenImageFetcher) {

        self.tokenImageFetcher = tokenImageFetcher
        self.currencyService = currencyService
        self.service = service
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
        tokenRowView.translatesAutoresizingMaskIntoConstraints = false

        let col0 = [
            pricePerTokenLabel,
            .spacer(height: 4),
            pricePerTokenField.defaultLayout(),
        ].asStackView(axis: .vertical)
        col0.translatesAutoresizingMaskIntoConstraints = false

        let sameHeightAsPricePerTokenAlternativeAmountLabelPlaceholder = UIView()
        sameHeightAsPricePerTokenAlternativeAmountLabelPlaceholder.translatesAutoresizingMaskIntoConstraints = false

        let col1 = [
            quantityLabel,
            .spacer(height: 4),
            quantityStepper,
            sameHeightAsPricePerTokenAlternativeAmountLabelPlaceholder,
        ].asStackView(axis: .vertical)
        col1.translatesAutoresizingMaskIntoConstraints = false

        let separator1 = UIView.separator()
        let separator2 = UIView.separator()

        containerView.stackView.addArrangedSubviews([
            .spacer(height: 18),
            tokenRowView,
            .spacer(height: 18),
            col0,
            .spacerWidth(10),
            col1,
            .spacer(height: 18),
            ethCostLabelLabel,
            .spacer(height: 10),
            separator1,
            .spacer(height: 10),
            ethCostLabel,
            .spacer(height: 10),
            separator2,
            .spacer(height: 10),
            dollarCostLabelLabel,
            .spacer(height: 10),
            dollarCostLabel,
        ])

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0.0)
        view.addSubview(containerView)
        view.addSubview(footerBar)

        let xOffset: CGFloat = 16

        NSLayoutConstraint.activate([
            quantityStepper.heightAnchor.constraint(equalToConstant: 50),

            tokenRowView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tokenRowView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            separator1.leadingAnchor.constraint(equalTo: tokenRowView.background.leadingAnchor),
            separator1.trailingAnchor.constraint(equalTo: tokenRowView.background.trailingAnchor),

            separator2.leadingAnchor.constraint(equalTo: tokenRowView.background.leadingAnchor),
            separator2.trailingAnchor.constraint(equalTo: tokenRowView.background.trailingAnchor),

            quantityStepper.widthAnchor.constraint(equalTo: containerView.widthAnchor),
            pricePerTokenField.widthAnchor.constraint(equalTo: containerView.widthAnchor),

            containerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: xOffset),
            containerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -xOffset),
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            footerBar.anchorsConstraint(to: view),
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        service.tokenViewModelPublisher(for: viewModel.ethToken)
            .map { [currencyService] tokenViewModel -> AmountTextFieldViewModel.CurrencyRate in
                guard let ticker = tokenViewModel?.balance.ticker else { return .init(value: nil, currency: currencyService.currency) }

                return AmountTextFieldViewModel.CurrencyRate(value: ticker.price_usd, currency: ticker.currency)
            }.sink { [weak pricePerTokenField] value in
                pricePerTokenField?.viewModel.cryptoToFiatRate.value = value
            }.store(in: &cancelable)

        pricePerTokenField.delegate = self

        quantityStepper.addTarget(self, action: #selector(quantityChanged), for: .valueChanged)

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
        guard quantityStepper.value > 0 else {
            let tokenTypeName = assetDefinitionStore.xmlHandler(forTokenScriptSupportable: viewModel.token).getNameInPluralForm()
            UIAlertController.alert(title: "",
                    message: R.string.localizable.aWalletTokenSellSelectTokenQuantityAtLeastOneTitle(tokenTypeName),
                    alertButtonTitles: [R.string.localizable.oK()],
                    alertButtonStyles: [.cancel],
                    viewController: self,
                    completion: nil)
            return
        }

        let noPrice: Bool
        //We must use `Ether(string:)` because the input string might not always use a decimal point as the decimal separator. It might use a decimal comma. E.g. "1.2" or "1,2" depending on locale
        switch pricePerTokenField.cryptoValue {
        case .notSet:
            noPrice = true
        case .allFunds(let amount):
            noPrice = amount == .zero
        case .amount(let amount):
            noPrice = amount == .zero
        }

        guard !noPrice else {
            let tokenTypeName = assetDefinitionStore.xmlHandler(forTokenScriptSupportable: viewModel.token).getNameInPluralForm()
            UIAlertController.alert(title: "",
                    message: R.string.localizable.aWalletTokenSellPriceProvideTitle(tokenTypeName),
                    alertButtonTitles: [R.string.localizable.oK()],
                    alertButtonStyles: [.cancel],
                    viewController: self,
                    completion: nil)
            return
        }

        delegate?.didEnterSellTokensPriceQuantity(token: viewModel.token, tokenHolder: getTokenHolderFromQuantity(), ethCost: totalEthCost, in: self)
    }

    @objc func quantityChanged() {
        updateTotalCostsLabels()
    }

    private func updateTotalCostsLabels() {
        viewModel.ethCost = totalEthCost
        viewModel.dollarCost = totalDollarCost
        configure(viewModel: viewModel)
    }

    func configure(viewModel newViewModel: EnterSellTokensCardPriceQuantityViewModel? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }
        updateNavigationRightBarButtons(withTokenScriptFileStatus: tokenScriptFileStatus)

        navigationItem.title = viewModel.headerTitle

        tokenRowView.configure(tokenHolder: viewModel.tokenHolder)
        pricePerTokenLabel.text = viewModel.pricePerTokenLabelText
        ethCostLabelLabel.text = viewModel.ethCostLabelLabelText
        ethCostLabel.text = viewModel.ethCostLabelText
        dollarCostLabelLabel.text = R.string.localizable.aWalletTokenSellDollarCostLabelTitle()
        dollarCostLabelLabel.isHidden = viewModel.hideDollarCost
        dollarCostLabel.text = viewModel.dollarCostLabelText
        dollarCostLabel.isHidden = viewModel.hideDollarCost
        quantityLabel.text = viewModel.quantityLabelText

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

extension EnterSellTokensCardPriceQuantityViewController: VerifiableStatusViewController {
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

extension EnterSellTokensCardPriceQuantityViewController: AmountTextFieldDelegate {

    func shouldReturn(in textField: AmountTextField) -> Bool {
        return true
    }

    func changeAmount(in textField: AmountTextField) {
        updateTotalCostsLabels()
    }

    func changeType(in textField: AmountTextField) {
        updateTotalCostsLabels()
    }

    func doneButtonTapped(for textField: AmountTextField) {
        view.endEditing(true)
    }
}

class PaddedLabel: UILabel {
    override init(frame: CGRect) {
        super.init(frame: frame)
        cornerRadius = DataEntry.Metric.CornerRadius.textbox
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + 30, height: size.height + 10)
    }
}
