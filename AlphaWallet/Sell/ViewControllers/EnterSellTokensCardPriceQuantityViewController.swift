// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import BigInt

protocol EnterSellTokensCardPriceQuantityViewControllerDelegate: class, CanOpenURL {
    func didEnterSellTokensPriceQuantity(token: TokenObject, tokenHolder: TokenHolder, ethCost: Ether, in viewController: EnterSellTokensCardPriceQuantityViewController)
    func didPressViewInfo(in viewController: EnterSellTokensCardPriceQuantityViewController)
}

class EnterSellTokensCardPriceQuantityViewController: UIViewController, TokenVerifiableStatusViewController {
    private let storage: TokensDataStore
    private let roundedBackground = RoundedBackground()
    private let scrollView = UIScrollView()
    private let header = TokensCardViewControllerTitleHeader()
    private let pricePerTokenLabel = UILabel()
	private let quantityLabel = UILabel()
    private let quantityStepper = NumberStepper()
    private let ethCostLabelLabel = UILabel()
    private let ethCostLabel = UILabel()
    private let dollarCostLabelLabel = UILabel()
    private let dollarCostLabel = PaddedLabel()
    private let tokenRowView: TokenRowView & UIView
    private let buttonsBar = ButtonsBar(numberOfButtons: 1)
    private var viewModel: EnterSellTokensCardPriceQuantityViewControllerViewModel
    private let ethPrice: Subscribable<Double>
    private var totalEthCost: Ether {
        if let ethCostPerToken = Ether(string: pricePerTokenField.ethCost) {
            let quantity = Int(quantityStepper.value)
            return ethCostPerToken * quantity
        } else {
            return .zero
        }
    }

    private var totalDollarCost: String {
        if let dollarCostPerToken = pricePerTokenField.dollarCost {
            let quantity = Double(quantityStepper.value)
            return StringFormatter().currency(with: dollarCostPerToken * quantity, and: "USD")
        } else {
            return ""
        }
    }

    var contract: AlphaWallet.Address {
        return viewModel.token.contractAddress
    }
    var server: RPCServer {
        return viewModel.token.server
    }
    let assetDefinitionStore: AssetDefinitionStore
    lazy var pricePerTokenField = AmountTextField(server: server)
    let paymentFlow: PaymentFlow
    weak var delegate: EnterSellTokensCardPriceQuantityViewControllerDelegate?

// swiftlint:disable function_body_length
    init(
            storage: TokensDataStore,
            paymentFlow: PaymentFlow,
            cryptoPrice: Subscribable<Double>,
            viewModel: EnterSellTokensCardPriceQuantityViewControllerViewModel,
            assetDefinitionStore: AssetDefinitionStore
    ) {
        self.storage = storage
        self.paymentFlow = paymentFlow
        self.ethPrice = cryptoPrice
        self.viewModel = viewModel
        self.assetDefinitionStore = assetDefinitionStore

        let tokenType = OpenSeaBackedNonFungibleTokenHandling(token: viewModel.token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified)
        switch tokenType {
        case .backedByOpenSea:
            tokenRowView = OpenSeaNonFungibleTokenCardRowView(tokenView: .viewIconified)
        case .notBackedByOpenSea:
            tokenRowView = TokenCardRowView(server: viewModel.token.server, tokenView: .viewIconified, assetDefinitionStore: assetDefinitionStore)
        }

        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(withTokenScriptFileStatus: nil)

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(scrollView)

        tokenRowView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(tokenRowView)

        pricePerTokenLabel.translatesAutoresizingMaskIntoConstraints = false
        quantityLabel.translatesAutoresizingMaskIntoConstraints = false
        ethCostLabelLabel.translatesAutoresizingMaskIntoConstraints = false
        dollarCostLabelLabel.translatesAutoresizingMaskIntoConstraints = false
        dollarCostLabel.translatesAutoresizingMaskIntoConstraints = false
        pricePerTokenField.translatesAutoresizingMaskIntoConstraints = false
        cryptoPrice.subscribe { [weak self] value in
            if let value = value {
                self?.pricePerTokenField.cryptoToDollarRate = value
            }
        }
        pricePerTokenField.delegate = self
        ethCostLabel.translatesAutoresizingMaskIntoConstraints = false
        quantityStepper.translatesAutoresizingMaskIntoConstraints = false
        quantityStepper.minimumValue = 1
        quantityStepper.value = 1
        quantityStepper.addTarget(self, action: #selector(quantityChanged), for: .valueChanged)

        let col0 = [
            pricePerTokenLabel,
            .spacer(height: 4),
            pricePerTokenField,
            pricePerTokenField.alternativeAmountLabel,
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

        let choicesStackView = [col0, .spacerWidth(10), col1].asStackView()
        choicesStackView.translatesAutoresizingMaskIntoConstraints = false

        let separator1 = UIView()
        separator1.backgroundColor = UIColor(red: 230, green: 230, blue: 230)

        let separator2 = UIView()
        separator2.backgroundColor = UIColor(red: 230, green: 230, blue: 230)

        let stackView = [
            header,
            tokenRowView,
            .spacer(height: 20),
            choicesStackView,
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
        ].asStackView(axis: .vertical, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = .clear
        roundedBackground.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)

        NSLayoutConstraint.activate([
			header.heightAnchor.constraint(equalToConstant: 90),

			quantityStepper.heightAnchor.constraint(equalToConstant: 50),

            sameHeightAsPricePerTokenAlternativeAmountLabelPlaceholder.heightAnchor.constraint(equalTo: pricePerTokenField.alternativeAmountLabel.heightAnchor),

            tokenRowView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tokenRowView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            separator1.heightAnchor.constraint(equalToConstant: 1),
            separator1.leadingAnchor.constraint(equalTo: tokenRowView.background.leadingAnchor),
            separator1.trailingAnchor.constraint(equalTo: tokenRowView.background.trailingAnchor),

            separator2.heightAnchor.constraint(equalToConstant: 1),
            separator2.leadingAnchor.constraint(equalTo: tokenRowView.background.leadingAnchor),
            separator2.trailingAnchor.constraint(equalTo: tokenRowView.background.trailingAnchor),

            pricePerTokenField.leadingAnchor.constraint(equalTo: tokenRowView.background.leadingAnchor),
            quantityStepper.rightAnchor.constraint(equalTo: tokenRowView.background.rightAnchor),

            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.topAnchor.constraint(equalTo: view.layoutGuide.bottomAnchor, constant: -ButtonsBar.buttonsHeight - ButtonsBar.marginAtBottomScreen),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            pricePerTokenField.widthAnchor.constraint(equalTo: quantityStepper.widthAnchor),
            pricePerTokenField.heightAnchor.constraint(equalTo: quantityStepper.heightAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }
// swiftlint:enable function_body_length

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    func nextButtonTapped() {
        guard quantityStepper.value > 0 else {
            let tokenTypeName = XMLHandler(contract: contract, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
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
        if let price = Double(Ether(string: pricePerTokenField.ethCost)?.unformattedDescription ?? "") {
            noPrice = price.isZero
        } else {
            noPrice = true
        }

        guard !noPrice else {
            let tokenTypeName = XMLHandler(contract: contract, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
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

    func configure(viewModel newViewModel: EnterSellTokensCardPriceQuantityViewControllerViewModel? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }
        updateNavigationRightBarButtons(withTokenScriptFileStatus: tokenScriptFileStatus)

        view.backgroundColor = viewModel.backgroundColor

        header.configure(title: viewModel.headerTitle)

        tokenRowView.configure(tokenHolder: viewModel.tokenHolder)

        pricePerTokenLabel.textAlignment = .center
        pricePerTokenLabel.textColor = viewModel.choiceLabelColor
        pricePerTokenLabel.font = viewModel.choiceLabelFont
        pricePerTokenLabel.text = viewModel.pricePerTokenLabelText

        ethCostLabelLabel.textAlignment = .center
        ethCostLabelLabel.textColor = viewModel.ethCostLabelLabelColor
        ethCostLabelLabel.font = viewModel.ethCostLabelLabelFont
        ethCostLabelLabel.text = viewModel.ethCostLabelLabelText

        ethCostLabel.textAlignment = .center
        ethCostLabel.textColor = viewModel.ethCostLabelColor
        ethCostLabel.font = viewModel.ethCostLabelFont
        ethCostLabel.text = viewModel.ethCostLabelText

        dollarCostLabelLabel.textAlignment = .center
        dollarCostLabelLabel.textColor = viewModel.dollarCostLabelLabelColor
        dollarCostLabelLabel.font = viewModel.dollarCostLabelLabelFont
        dollarCostLabelLabel.text = R.string.localizable.aWalletTokenSellDollarCostLabelTitle()
        dollarCostLabelLabel.isHidden = viewModel.hideDollarCost

        dollarCostLabel.textAlignment = .center
        dollarCostLabel.textColor = viewModel.dollarCostLabelColor
        dollarCostLabel.font = viewModel.dollarCostLabelFont
        dollarCostLabel.text = viewModel.dollarCostLabelText
        dollarCostLabel.backgroundColor = viewModel.dollarCostLabelBackgroundColor
        dollarCostLabel.layer.masksToBounds = true
        dollarCostLabel.isHidden = viewModel.hideDollarCost

        quantityLabel.textAlignment = .center
        quantityLabel.textColor = viewModel.choiceLabelColor
        quantityLabel.font = viewModel.choiceLabelFont
        quantityLabel.text = viewModel.quantityLabelText

        quantityStepper.maximumValue = viewModel.maxValue

        tokenRowView.stateLabel.isHidden = true

        buttonsBar.configure()

        let nextButton = buttonsBar.buttons[0]
        nextButton.setTitle(R.string.localizable.aWalletNextButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
    }

    private func getTokenHolderFromQuantity() -> TokenHolder {
        let quantity = quantityStepper.value
        let tokenHolder = viewModel.tokenHolder
        let tokens = Array(tokenHolder.tokens[..<quantity])
        return TokenHolder(
            tokens: tokens,
            contractAddress: tokenHolder.contractAddress,
            hasAssetDefinition: tokenHolder.hasAssetDefinition
        )
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
    func changeAmount(in textField: AmountTextField) {
        updateTotalCostsLabels()
    }

    func changeType(in textField: AmountTextField) {
        updateTotalCostsLabels()
    }
}

class PaddedLabel: UILabel {
    override init(frame: CGRect) {
        super.init(frame: frame)
        cornerRadius = Metrics.CornerRadius.textbox
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + 30, height: size.height + 10)
    }
}
