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
    private let nextButton = UIButton(type: .system)
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

    let config: Config
    var contract: String {
        return viewModel.token.contract
    }
    let pricePerTokenField = AmountTextField()
    let paymentFlow: PaymentFlow
    weak var delegate: EnterSellTokensCardPriceQuantityViewControllerDelegate?

    init(
            config: Config,
            storage: TokensDataStore,
            paymentFlow: PaymentFlow,
            ethPrice: Subscribable<Double>,
            viewModel: EnterSellTokensCardPriceQuantityViewControllerViewModel
    ) {
        self.config = config
        self.storage = storage
        self.paymentFlow = paymentFlow
        self.ethPrice = ethPrice
        self.viewModel = viewModel

        let tokenType = OpenSeaNonFungibleTokenHandling(token: viewModel.token)
        switch tokenType {
        case .supportedByOpenSea:
            tokenRowView = OpenSeaNonFungibleTokenCardRowView()
        case .notSupportedByOpenSea:
            tokenRowView = TokenCardRowView()
        }

        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(isVerified: true)

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(scrollView)

        nextButton.setTitle(R.string.localizable.aWalletNextButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)

        tokenRowView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(tokenRowView)

        pricePerTokenLabel.translatesAutoresizingMaskIntoConstraints = false
        quantityLabel.translatesAutoresizingMaskIntoConstraints = false
        ethCostLabelLabel.translatesAutoresizingMaskIntoConstraints = false
        dollarCostLabelLabel.translatesAutoresizingMaskIntoConstraints = false
        dollarCostLabel.translatesAutoresizingMaskIntoConstraints = false

        pricePerTokenField.translatesAutoresizingMaskIntoConstraints = false
        if config.chainID == 100 {
            self.pricePerTokenField.cryptoToDollarRate = 1
        } else {
            ethPrice.subscribe { [weak self] value in
                if let value = value {
                    self?.pricePerTokenField.cryptoToDollarRate = value
                }
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

        let buttonsStackView = [nextButton].asStackView(distribution: .fillEqually, contentHuggingPriority: .required)
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = Colors.appHighlightGreen
        roundedBackground.addSubview(footerBar)

        let buttonsHeight = Metrics.greenButtonHeight
        footerBar.addSubview(buttonsStackView)

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

            buttonsStackView.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsStackView.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsStackView.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsStackView.heightAnchor.constraint(equalToConstant: buttonsHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.topAnchor.constraint(equalTo: view.layoutGuide.bottomAnchor, constant: -buttonsHeight),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            pricePerTokenField.widthAnchor.constraint(equalTo: quantityStepper.widthAnchor),
            pricePerTokenField.heightAnchor.constraint(equalTo: quantityStepper.heightAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    func nextButtonTapped() {
        guard quantityStepper.value > 0 else {
            let tokenTypeName = XMLHandler(contract: contract).getTokenTypeName()
            UIAlertController.alert(title: "",
                    message: R.string.localizable.aWalletTokenSellSelectTokenQuantityAtLeastOneTitle(tokenTypeName),
                    alertButtonTitles: [R.string.localizable.oK()],
                    alertButtonStyles: [.cancel],
                    viewController: self,
                    completion: nil)
            return
        }

        let noPrice: Bool
        if let price = Double(pricePerTokenField.ethCost) {
            noPrice = price.isZero
        } else {
            noPrice = true
        }

        guard !noPrice else {
            let tokenTypeName = XMLHandler(contract: contract).getTokenTypeName(.plural, titlecase: .notTitlecase)
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

    func showInfo() {
        delegate?.didPressViewInfo(in: self)
    }

    func showContractWebPage() {
        delegate?.didPressViewContractWebPage(forContract: contract, in: self)
    }

    func configure(viewModel newViewModel: EnterSellTokensCardPriceQuantityViewControllerViewModel? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }
        updateNavigationRightBarButtons(isVerified: isContractVerified)

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

        quantityStepper.borderWidth = 1
        quantityStepper.clipsToBounds = true
        quantityStepper.borderColor = viewModel.stepperBorderColor
        quantityStepper.maximumValue = viewModel.maxValue

        tokenRowView.stateLabel.isHidden = true

        nextButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
		nextButton.backgroundColor = viewModel.buttonBackgroundColor
        nextButton.titleLabel?.font = viewModel.buttonFont
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        quantityStepper.layer.cornerRadius = quantityStepper.frame.size.height / 2
        pricePerTokenField.layer.cornerRadius = quantityStepper.frame.size.height / 2
        //We can't use height / 2 because for some unknown reason, dollarCostLabel still has a zero height here
//        dollarCostLabel.layer.cornerRadius = dollarCostLabel.frame.size.height / 2
        dollarCostLabel.layer.cornerRadius = 18
    }

    class PaddedLabel: UILabel {
        override var intrinsicContentSize: CGSize {
            let size = super.intrinsicContentSize
            return CGSize(width: size.width + 30, height: size.height + 10)
        }
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
