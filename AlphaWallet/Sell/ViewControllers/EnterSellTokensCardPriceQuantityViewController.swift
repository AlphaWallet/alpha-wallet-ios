// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import BigInt

protocol EnterSellTokensCardPriceQuantityViewControllerDelegate: class {
    func didEnterSellTicketsPriceQuantity(token: TokenObject, ticketHolder: TokenHolder, ethCost: Ether, in viewController: EnterSellTokensCardPriceQuantityViewController)
    func didPressViewInfo(in viewController: EnterSellTokensCardPriceQuantityViewController)
    func didPressViewContractWebPage(in viewController: EnterSellTokensCardPriceQuantityViewController)
}

class EnterSellTokensCardPriceQuantityViewController: UIViewController, TokenVerifiableStatusViewController {

    let config: Config
    var contract: String {
        return viewModel.token.contract
    }
    let storage: TokensDataStore
    let roundedBackground = RoundedBackground()
    let scrollView = UIScrollView()
    let header = TokensCardViewControllerTitleHeader()
    let pricePerTicketLabel = UILabel()
    let pricePerTicketField = AmountTextField()
	let quantityLabel = UILabel()
    let quantityStepper = NumberStepper()
    let ethCostLabelLabel = UILabel()
    let ethCostLabel = UILabel()
    let dollarCostLabelLabel = UILabel()
    let dollarCostLabel = PaddedLabel()
    let ticketView: TokenRowView & UIView
    let nextButton = UIButton(type: .system)
    var viewModel: EnterSellTokensCardPriceQuantityViewControllerViewModel
    let paymentFlow: PaymentFlow
    let ethPrice: Subscribable<Double>
    var totalEthCost: Ether {
        if let ethCostPerTicket = Ether(string: pricePerTicketField.ethCost) {
            let quantity = Int(quantityStepper.value)
            return ethCostPerTicket * quantity
        } else {
            return .zero
        }
    }

    var totalDollarCost: String {
        if let dollarCostPerTicket = Double(pricePerTicketField.dollarCost) {
            let quantity = Double(quantityStepper.value)
            return StringFormatter().currency(with: dollarCostPerTicket * quantity, and: "USD")
        } else {
            return ""
        }
    }
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

        let tokenType = CryptoKittyHandling(address: viewModel.token.address)
        switch tokenType {
        case .cryptoKitty:
            ticketView = TokenListFormatRowView()
        case .otherNonFungibleToken:
            ticketView = TokenCardRowView()
        }

        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(isVerified: true)

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(scrollView)

        nextButton.setTitle(R.string.localizable.aWalletNextButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)

        ticketView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(ticketView)

        pricePerTicketLabel.translatesAutoresizingMaskIntoConstraints = false
        quantityLabel.translatesAutoresizingMaskIntoConstraints = false
        ethCostLabelLabel.translatesAutoresizingMaskIntoConstraints = false
        dollarCostLabelLabel.translatesAutoresizingMaskIntoConstraints = false
        dollarCostLabel.translatesAutoresizingMaskIntoConstraints = false

        pricePerTicketField.translatesAutoresizingMaskIntoConstraints = false
        ethPrice.subscribe { [weak self] value in
            if let value = value {
                self?.pricePerTicketField.ethToDollarRate = value
            }
        }
        pricePerTicketField.delegate = self

        ethCostLabel.translatesAutoresizingMaskIntoConstraints = false

        quantityStepper.translatesAutoresizingMaskIntoConstraints = false
        quantityStepper.minimumValue = 1
        quantityStepper.value = 1
        quantityStepper.addTarget(self, action: #selector(quantityChanged), for: .valueChanged)

        let col0 = [
            pricePerTicketLabel,
            .spacer(height: 4),
            pricePerTicketField,
            pricePerTicketField.alternativeAmountLabel,
        ].asStackView(axis: .vertical)
        col0.translatesAutoresizingMaskIntoConstraints = false

        let sameHeightAsPricePerTicketAlternativeAmountLabelPlaceholder = UIView()
        sameHeightAsPricePerTicketAlternativeAmountLabelPlaceholder.translatesAutoresizingMaskIntoConstraints = false

        let col1 = [
            quantityLabel,
            .spacer(height: 4),
            quantityStepper,
            sameHeightAsPricePerTicketAlternativeAmountLabelPlaceholder,
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
            ticketView,
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

            sameHeightAsPricePerTicketAlternativeAmountLabelPlaceholder.heightAnchor.constraint(equalTo: pricePerTicketField.alternativeAmountLabel.heightAnchor),

            ticketView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ticketView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            separator1.heightAnchor.constraint(equalToConstant: 1),
            separator1.leadingAnchor.constraint(equalTo: ticketView.background.leadingAnchor),
            separator1.trailingAnchor.constraint(equalTo: ticketView.background.trailingAnchor),

            separator2.heightAnchor.constraint(equalToConstant: 1),
            separator2.leadingAnchor.constraint(equalTo: ticketView.background.leadingAnchor),
            separator2.trailingAnchor.constraint(equalTo: ticketView.background.trailingAnchor),

            pricePerTicketField.leadingAnchor.constraint(equalTo: ticketView.background.leadingAnchor),
            quantityStepper.rightAnchor.constraint(equalTo: ticketView.background.rightAnchor),

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

            pricePerTicketField.widthAnchor.constraint(equalTo: quantityStepper.widthAnchor),
            pricePerTicketField.heightAnchor.constraint(equalTo: quantityStepper.heightAnchor),
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
                    message: R.string.localizable.aWalletTicketTokenSellSelectTicketQuantityAtLeastOneTitle(tokenTypeName),
                    alertButtonTitles: [R.string.localizable.oK()],
                    alertButtonStyles: [.cancel],
                    viewController: self,
                    completion: nil)
            return
        }

        let noPrice: Bool
        if let price = Double(pricePerTicketField.ethCost) {
            noPrice = price.isZero
        } else {
            noPrice = true
        }

        guard !noPrice else {
            let tokenTypeName = XMLHandler(contract: contract).getTokenTypeName(.plural, titlecase: .notTitlecase)
            UIAlertController.alert(title: "",
                    message: R.string.localizable.aWalletTicketTokenSellPriceProvideTitle(tokenTypeName),
                    alertButtonTitles: [R.string.localizable.oK()],
                    alertButtonStyles: [.cancel],
                    viewController: self,
                    completion: nil)
            return
        }

        delegate?.didEnterSellTicketsPriceQuantity(token: viewModel.token, ticketHolder: getTicketHolderFromQuantity(), ethCost: totalEthCost, in: self)
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
        delegate?.didPressViewContractWebPage(in: self)
    }

    func configure(viewModel newViewModel: EnterSellTokensCardPriceQuantityViewControllerViewModel? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }
        updateNavigationRightBarButtons(isVerified: isContractVerified)

        view.backgroundColor = viewModel.backgroundColor

        header.configure(title: viewModel.headerTitle)

        ticketView.configure(tokenHolder: viewModel.ticketHolder)

        pricePerTicketLabel.textAlignment = .center
        pricePerTicketLabel.textColor = viewModel.choiceLabelColor
        pricePerTicketLabel.font = viewModel.choiceLabelFont
        pricePerTicketLabel.text = viewModel.pricePerTicketLabelText

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
        dollarCostLabelLabel.text = R.string.localizable.aWalletTicketTokenSellDollarCostLabelTitle()
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

        ticketView.stateLabel.isHidden = true

        nextButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
		nextButton.backgroundColor = viewModel.buttonBackgroundColor
        nextButton.titleLabel?.font = viewModel.buttonFont
    }

    private func getTicketHolderFromQuantity() -> TokenHolder {
        let quantity = quantityStepper.value
        let ticketHolder = viewModel.ticketHolder
        let tickets = Array(ticketHolder.tickets[..<quantity])
        return TokenHolder(
            tickets: tickets,
            status: ticketHolder.status,
            contractAddress: ticketHolder.contractAddress
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        quantityStepper.layer.cornerRadius = quantityStepper.frame.size.height / 2
        pricePerTicketField.layer.cornerRadius = quantityStepper.frame.size.height / 2
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
