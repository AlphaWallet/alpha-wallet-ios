// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol EnterSellTokensPriceQuantityViewControllerDelegate: class {
    func didEnterSellTokensPriceQuantity(token: TokenObject, TokenHolder: TokenHolder, ethCost: String, in viewController: EnterSellTokensPriceQuantityViewController)
    func didPressViewInfo(in viewController: EnterSellTokensPriceQuantityViewController)
    func didPressViewContractWebPage(in viewController: EnterSellTokensPriceQuantityViewController)
}

class EnterSellTokensPriceQuantityViewController: UIViewController, TokenVerifiableStatusViewController {

    let config: Config
    var contract: String {
        return viewModel.token.contract
    }
    let storage: TokensDataStore
    let roundedBackground = RoundedBackground()
    let scrollView = UIScrollView()
    let header = TokensViewControllerTitleHeader()
    let pricePerTokenLabel = UILabel()
    let pricePerTokenField = AmountTextField()
	let quantityLabel = UILabel()
    let quantityStepper = NumberStepper()
    let ethCostLabelLabel = UILabel()
    let ethCostLabel = UILabel()
    let dollarCostLabelLabel = UILabel()
    let dollarCostLabel = PaddedLabel()
    let TokenView: TokenRowView & UIView
    let nextButton = UIButton(type: .system)
    var viewModel: EnterSellTokensPriceQuantityViewControllerViewModel
    var paymentFlow: PaymentFlow
    var ethPrice: Subscribable<Double>
    var totalEthCost: Double {
        if let ethCostPerToken = Double(pricePerTokenField.ethCost) {
            let quantity = Double(quantityStepper.value)
            return ethCostPerToken * quantity
        } else {
            return 0
        }
    }

    var totalDollarCost: String {
        if let dollarCostPerToken = Double(pricePerTokenField.dollarCost) {
            let quantity = Double(quantityStepper.value)
            return String(dollarCostPerToken * quantity)
        } else {
            return ""
        }
    }
    weak var delegate: EnterSellTokensPriceQuantityViewControllerDelegate?

    init(
            config: Config,
            storage: TokensDataStore,
            paymentFlow: PaymentFlow,
            ethPrice: Subscribable<Double>,
            viewModel: EnterSellTokensPriceQuantityViewControllerViewModel
    ) {
        self.config = config
        self.storage = storage
        self.paymentFlow = paymentFlow
        self.ethPrice = ethPrice
        self.viewModel = viewModel

        let tokenType = CryptoKittyHandling(address: viewModel.token.address)
        switch tokenType {
        case .cryptoKitty:
            TokenView = TokenListFormatRowView()
        case .otherNonFungibleToken:
            TokenView = TokenRowView()
        }

        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(isVerified: true)

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(scrollView)

        nextButton.setTitle(R.string.localizable.aWalletNextButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)

        TokenView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(TokenView)

        pricePerTokenLabel.translatesAutoresizingMaskIntoConstraints = false
        quantityLabel.translatesAutoresizingMaskIntoConstraints = false
        ethCostLabelLabel.translatesAutoresizingMaskIntoConstraints = false
        dollarCostLabelLabel.translatesAutoresizingMaskIntoConstraints = false
        dollarCostLabel.translatesAutoresizingMaskIntoConstraints = false

        pricePerTokenField.translatesAutoresizingMaskIntoConstraints = false
        ethPrice.subscribe { [weak self] value in
            if let value = value {
                self?.pricePerTokenField.ethToDollarRate = value
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
            TokenView,
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

        let buttonsHeight = CGFloat(60)
        footerBar.addSubview(buttonsStackView)

        NSLayoutConstraint.activate([
			header.heightAnchor.constraint(equalToConstant: 90),

			quantityStepper.heightAnchor.constraint(equalToConstant: 50),

            sameHeightAsPricePerTokenAlternativeAmountLabelPlaceholder.heightAnchor.constraint(equalTo: pricePerTokenField.alternativeAmountLabel.heightAnchor),

            TokenView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            TokenView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            separator1.heightAnchor.constraint(equalToConstant: 1),
            separator1.leadingAnchor.constraint(equalTo: TokenView.background.leadingAnchor),
            separator1.trailingAnchor.constraint(equalTo: TokenView.background.trailingAnchor),

            separator2.heightAnchor.constraint(equalToConstant: 1),
            separator2.leadingAnchor.constraint(equalTo: TokenView.background.leadingAnchor),
            separator2.trailingAnchor.constraint(equalTo: TokenView.background.trailingAnchor),

            pricePerTokenField.leadingAnchor.constraint(equalTo: TokenView.background.leadingAnchor),
            quantityStepper.rightAnchor.constraint(equalTo: TokenView.background.rightAnchor),

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
            footerBar.heightAnchor.constraint(equalToConstant: buttonsHeight),
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
            UIAlertController.alert(title: "",
                    message: R.string.localizable.aWalletTokenTokenSellSelectTokenQuantityAtLeastOneTitle(),
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
            UIAlertController.alert(title: "",
                    message: R.string.localizable.aWalletTokenTokenSellPriceProvideTitle(),
                    alertButtonTitles: [R.string.localizable.oK()],
                    alertButtonStyles: [.cancel],
                    viewController: self,
                    completion: nil)
            return
        }

        delegate?.didEnterSellTokensPriceQuantity(token: viewModel.token, TokenHolder: getTokenHolderFromQuantity(), ethCost: String(totalEthCost), in: self)
    }

    @objc func quantityChanged() {
        updateTotalCostsLabels()
    }

    private func updateTotalCostsLabels() {
        viewModel.ethCost = String(totalEthCost)
        viewModel.dollarCost = String(totalDollarCost)
        configure(viewModel: viewModel)
    }

    func showInfo() {
        delegate?.didPressViewInfo(in: self)
    }

    func showContractWebPage() {
        delegate?.didPressViewContractWebPage(in: self)
    }

    func configure(viewModel newViewModel: EnterSellTokensPriceQuantityViewControllerViewModel? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }
        updateNavigationRightBarButtons(isVerified: isContractVerified)

        view.backgroundColor = viewModel.backgroundColor

        header.configure(title: viewModel.headerTitle)

        TokenView.configure(tokenHolder: viewModel.TokenHolder)

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
        dollarCostLabelLabel.text = R.string.localizable.aWalletTokenTokenSellDollarCostLabelTitle()
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

        TokenView.stateLabel.isHidden = true

        nextButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
		nextButton.backgroundColor = viewModel.buttonBackgroundColor
        nextButton.titleLabel?.font = viewModel.buttonFont
    }

    private func getTokenHolderFromQuantity() -> TokenHolder {
        let quantity = quantityStepper.value
        let TokenHolder = viewModel.TokenHolder
        let Tokens = Array(TokenHolder.Tokens[..<quantity])
        return TokenHolder(
            Tokens: Tokens,
            status: TokenHolder.status,
            contractAddress: TokenHolder.contractAddress
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

extension EnterSellTokensPriceQuantityViewController: AmountTextFieldDelegate {
    func changeAmount(in textField: AmountTextField) {
        updateTotalCostsLabels()
    }

    func changeType(in textField: AmountTextField) {
        updateTotalCostsLabels()
    }
}
