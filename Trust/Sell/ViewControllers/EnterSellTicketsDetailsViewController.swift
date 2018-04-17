// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol EnterSellTicketsDetailsViewControllerDelegate: class {
    func didEnterSellTicketDetails(ticketHolder: TicketHolder, linkExpiryDate: Date, ethCost: String, dollarCost: String, in viewController: EnterSellTicketsDetailsViewController)
    func didPressViewInfo(in viewController: EnterSellTicketsDetailsViewController)
}

class EnterSellTicketsDetailsViewController: UIViewController {

    let storage: TokensDataStore
    //roundedBackground is used to achieve the top 2 rounded corners-only effect since maskedCorners to not round bottom corners is not available in iOS 10
    let roundedBackground = UIView()
    let scrollView = UIScrollView()
    let header = TicketsViewControllerTitleHeader()
    let subtitleLabel = UILabel()
    let ethHelpButton = UIButton(type: .system)
    let pricePerTicketLabel = UILabel()
    let pricePerTicketField = AmountTextField()
	let quantityLabel = UILabel()
    let quantityStepper = NumberStepper()
    let linkExpiryDateLabel = UILabel()
    let linkExpiryDateField = DateEntryField()
    let linkExpiryTimeLabel = UILabel()
    let linkExpiryTimeField = TimeEntryField()
    let totalCostLabel = UILabel()
    let costLabel = UILabel()
    let ticketView = TicketRowView()
    let nextButton = UIButton(type: .system)
    var datePicker = UIDatePicker()
    var timePicker = UIDatePicker()
    var viewModel: SellTicketsQuantitySelectionViewModel!
    var paymentFlow: PaymentFlow
    weak var delegate: EnterSellTicketsDetailsViewControllerDelegate?

    init(storage: TokensDataStore, paymentFlow: PaymentFlow) {
        self.storage = storage
        self.paymentFlow = paymentFlow
        super.init(nibName: nil, bundle: nil)

        navigationItem.rightBarButtonItem = UIBarButtonItem(image: R.image.location(), style: .plain, target: self, action: #selector(showInfo))

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.backgroundColor = Colors.appWhite
        roundedBackground.cornerRadius = 20
        view.addSubview(roundedBackground)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(scrollView)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        ethHelpButton.setTitle(R.string.localizable.aWalletTicketTokenSellLearnAboutEthButtonTitle(), for: .normal)
        ethHelpButton.addTarget(self, action: #selector(learnMoreAboutEthereumTapped), for: .touchUpInside)

        nextButton.setTitle(R.string.localizable.aWalletTicketTokenSellGenerateLinkButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)

        ticketView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(ticketView)

        pricePerTicketLabel.translatesAutoresizingMaskIntoConstraints = false
        quantityLabel.translatesAutoresizingMaskIntoConstraints = false
        linkExpiryDateLabel.translatesAutoresizingMaskIntoConstraints = false
        linkExpiryTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        totalCostLabel.translatesAutoresizingMaskIntoConstraints = false

        pricePerTicketField.translatesAutoresizingMaskIntoConstraints = false
        //TODO is there a better way to get the price?
        if let rates = storage.tickers, let ticker = rates.values.first(where: { $0.symbol == "ETH" }), let price = Double(ticker.price) {
            pricePerTicketField.ethToDollarRate = price
        }
        pricePerTicketField.delegate = self

        costLabel.translatesAutoresizingMaskIntoConstraints = false

        linkExpiryDateField.translatesAutoresizingMaskIntoConstraints = false
        linkExpiryDateField.value = Date.yesterday
        linkExpiryDateField.delegate = self

        linkExpiryTimeField.translatesAutoresizingMaskIntoConstraints = false
        linkExpiryTimeField.delegate = self

        quantityStepper.translatesAutoresizingMaskIntoConstraints = false
        quantityStepper.minimumValue = 1
        quantityStepper.value = 1

        let col0 = UIStackView(arrangedSubviews: [
            pricePerTicketLabel,
            .spacer(height: 4),
            pricePerTicketField,
            pricePerTicketField.alternativeAmountLabel,
            .spacer(height: 16),
            linkExpiryDateLabel,
            .spacer(height: 4),
            linkExpiryDateField,
        ])
        col0.translatesAutoresizingMaskIntoConstraints = false
        col0.axis = .vertical
        col0.spacing = 0
        col0.distribution = .fill

        let sameHeightAsPricePerTicketAlternativeAmountLabelPlaceholder = UIView()
        sameHeightAsPricePerTicketAlternativeAmountLabelPlaceholder.translatesAutoresizingMaskIntoConstraints = false

        let col1 = UIStackView(arrangedSubviews: [
            quantityLabel,
            .spacer(height: 4),
            quantityStepper,
            sameHeightAsPricePerTicketAlternativeAmountLabelPlaceholder,
            .spacer(height: 16),
            linkExpiryTimeLabel,
            .spacer(height: 4),
            linkExpiryTimeField,
        ])
        col1.translatesAutoresizingMaskIntoConstraints = false
        col1.axis = .vertical
        col1.spacing = 0
        col1.distribution = .fill

        let choicesStackView = UIStackView(arrangedSubviews: [
            col0,
            .spacerWidth(10),
            col1,
        ])
        choicesStackView.translatesAutoresizingMaskIntoConstraints = false
        choicesStackView.axis = .horizontal
        choicesStackView.spacing = 0
        choicesStackView.distribution = .fill

        datePicker.datePickerMode = .date
        datePicker.minimumDate = Date()
        datePicker.addTarget(self, action: #selector(datePickerValueChanged), for: .valueChanged)
        datePicker.isHidden = true

        timePicker.datePickerMode = .time
        timePicker.minimumDate = Date()
        timePicker.addTarget(self, action: #selector(timePickerValueChanged), for: .valueChanged)
        timePicker.isHidden = true

        let separator = UIView()
        separator.backgroundColor = UIColor(red: 230, green: 230, blue: 230)

        let stackView = UIStackView(arrangedSubviews: [
            header,
            subtitleLabel,
            .spacer(height: 16),
            ethHelpButton,
            .spacer(height: 30),
            ticketView,
            .spacer(height: 20),
            choicesStackView,
            datePicker,
            timePicker,
            .spacer(height: 18),
            totalCostLabel,
            .spacer(height: 10),
            separator,
            .spacer(height: 10),
            costLabel,
        ])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.distribution = .fill
		stackView.alignment = .center
        scrollView.addSubview(stackView)

        let buttonsStackView = UIStackView(arrangedSubviews: [nextButton])
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
        buttonsStackView.axis = .horizontal
        buttonsStackView.spacing = 0
        buttonsStackView.distribution = .fillEqually
        buttonsStackView.setContentHuggingPriority(.required, for: .horizontal)

        let marginToHideBottomRoundedCorners = CGFloat(30)
        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = Colors.appHighlightGreen
        roundedBackground.addSubview(footerBar)

        let buttonsHeight = CGFloat(60)
        footerBar.addSubview(buttonsStackView)

        NSLayoutConstraint.activate([
			header.heightAnchor.constraint(equalToConstant: 90),
            //Strange repositioning of header horizontally while typing without this
            header.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),

			quantityStepper.heightAnchor.constraint(equalToConstant: 50),

            sameHeightAsPricePerTicketAlternativeAmountLabelPlaceholder.heightAnchor.constraint(equalTo: pricePerTicketField.alternativeAmountLabel.heightAnchor),

            ticketView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ticketView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            roundedBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            roundedBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            roundedBackground.topAnchor.constraint(equalTo: view.topAnchor),
            roundedBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: marginToHideBottomRoundedCorners),

            separator.heightAnchor.constraint(equalToConstant: 1),
            separator.leadingAnchor.constraint(equalTo: ticketView.background.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: ticketView.background.trailingAnchor),

            pricePerTicketField.leadingAnchor.constraint(equalTo: ticketView.background.leadingAnchor),
            quantityStepper.rightAnchor.constraint(equalTo: ticketView.background.rightAnchor),
            linkExpiryDateField.leadingAnchor.constraint(equalTo: ticketView.background.leadingAnchor),
            linkExpiryTimeField.rightAnchor.constraint(equalTo: ticketView.background.rightAnchor),

            datePicker.leadingAnchor.constraint(equalTo: ticketView.background.leadingAnchor),
            datePicker.trailingAnchor.constraint(equalTo: ticketView.background.trailingAnchor),

            timePicker.leadingAnchor.constraint(equalTo: ticketView.background.leadingAnchor),
            timePicker.trailingAnchor.constraint(equalTo: ticketView.background.trailingAnchor),

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
            linkExpiryDateField.widthAnchor.constraint(equalTo: quantityStepper.widthAnchor),
            linkExpiryDateField.heightAnchor.constraint(equalTo: quantityStepper.heightAnchor),
            linkExpiryTimeField.widthAnchor.constraint(equalTo: quantityStepper.widthAnchor),
            linkExpiryTimeField.heightAnchor.constraint(equalTo: quantityStepper.heightAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    func nextButtonTapped() {
        guard quantityStepper.value > 0 else {
            UIAlertController.alert(title: "",
                    message: R.string.localizable.aWalletTicketTokenSellSelectTicketQuantityAtLeastOneTitle(),
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
            UIAlertController.alert(title: "",
                    message: R.string.localizable.aWalletTicketTokenSellPriceProvideTitle(),
                    alertButtonTitles: [R.string.localizable.oK()],
                    alertButtonStyles: [.cancel],
                    viewController: self,
                    completion: nil)
            return
        }

        //TODO be good if we check if date chosen is not too far into the future. Example 1 year ahead. Common error?

        delegate?.didEnterSellTicketDetails(ticketHolder: getTicketHolderFromQuantity(), linkExpiryDate: linkExpiryDate(), ethCost: pricePerTicketField.ethCost, dollarCost: pricePerTicketField.dollarCost, in: self)
    }

    private func linkExpiryDate() -> Date {
        let hour = NSCalendar.current.component(.hour, from: linkExpiryTimeField.value)
        let minutes = NSCalendar.current.component(.minute, from: linkExpiryTimeField.value)
        let seconds = NSCalendar.current.component(.second, from: linkExpiryTimeField.value)
        if let date = NSCalendar.current.date(bySettingHour: hour, minute: minutes, second: seconds, of: linkExpiryDateField.value) {
            return date
        } else {
            return Date()
        }
    }


    @objc func learnMoreAboutEthereumTapped() {
        showInfo()
    }

    @objc func showInfo() {
        delegate?.didPressViewInfo(in: self)
    }

    func configure(viewModel: SellTicketsQuantitySelectionViewModel) {
        self.viewModel = viewModel

        view.backgroundColor = viewModel.backgroundColor

        header.configure(title: viewModel.headerTitle)

        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = viewModel.subtitleLabelColor
        subtitleLabel.font = viewModel.subtitleLabelFont
        subtitleLabel.text = viewModel.subtitleLabelText

        ethHelpButton.titleLabel?.font = viewModel.ethHelpButtonFont

        ticketView.configure(viewModel: .init())

        pricePerTicketLabel.textAlignment = .center
        pricePerTicketLabel.textColor = viewModel.subtitleLabelColor
        pricePerTicketLabel.font = viewModel.choiceLabelFont
        pricePerTicketLabel.text = viewModel.pricePerTicketLabelText

        linkExpiryDateLabel.textAlignment = .center
        linkExpiryDateLabel.textColor = viewModel.subtitleLabelColor
        linkExpiryDateLabel.font = viewModel.choiceLabelFont
        linkExpiryDateLabel.text = viewModel.linkExpiryDateLabelText

        linkExpiryTimeLabel.textAlignment = .center
        linkExpiryTimeLabel.textColor = viewModel.subtitleLabelColor
        linkExpiryTimeLabel.font = viewModel.choiceLabelFont
        linkExpiryTimeLabel.text = viewModel.linkExpiryTimeLabelText

        totalCostLabel.textAlignment = .center
        totalCostLabel.textColor = viewModel.totalCostLabelColor
        totalCostLabel.font = viewModel.totalCostLabelFont
        totalCostLabel.text = viewModel.totalCostLabelText

        costLabel.textAlignment = .center
        costLabel.textColor = viewModel.costLabelColor
        costLabel.font = viewModel.costLabelFont
        costLabel.text = viewModel.costLabelText

        quantityLabel.textAlignment = .center
        quantityLabel.textColor = viewModel.choiceLabelColor
        quantityLabel.font = viewModel.choiceLabelFont
        quantityLabel.text = viewModel.quantityLabelText

        quantityStepper.borderWidth = 1
        quantityStepper.clipsToBounds = true
        quantityStepper.borderColor = viewModel.stepperBorderColor
        quantityStepper.maximumValue = viewModel.maxValue

        ticketView.stateLabel.isHidden = true

        ticketView.ticketCountLabel.text = viewModel.ticketCount

        ticketView.titleLabel.text = viewModel.title

        ticketView.venueLabel.text = viewModel.venue

        ticketView.dateLabel.text = viewModel.date

        ticketView.seatRangeLabel.text = viewModel.seatRange

        ticketView.zoneNameLabel.text = viewModel.zoneName

        nextButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
		nextButton.backgroundColor = viewModel.buttonBackgroundColor
        nextButton.titleLabel?.font = viewModel.buttonFont
    }

    private func getTicketHolderFromQuantity() -> TicketHolder {
        let quantity = quantityStepper.value
        let ticketHolder = viewModel.ticketHolder
        let tickets = Array(ticketHolder.tickets[..<quantity])
        return TicketHolder(
            tickets: tickets,
            zone: ticketHolder.zone,
            name: ticketHolder.name,
            venue: ticketHolder.venue,
            date: ticketHolder.date,
            status: ticketHolder.status
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        quantityStepper.layer.cornerRadius = quantityStepper.frame.size.height / 2
        pricePerTicketField.layer.cornerRadius = quantityStepper.frame.size.height / 2
        linkExpiryDateField.layer.cornerRadius = linkExpiryDateField.frame.size.height / 2
        linkExpiryTimeField.layer.cornerRadius = linkExpiryTimeField.frame.size.height / 2
    }

    @objc func datePickerValueChanged() {
        linkExpiryDateField.value = datePicker.date
    }

    @objc func timePickerValueChanged() {
        linkExpiryTimeField.value = timePicker.date
    }
}

extension EnterSellTicketsDetailsViewController: DateEntryFieldDelegate {
    func didTap(in dateEntryField: DateEntryField) {
        datePicker.isHidden = !datePicker.isHidden
        if !datePicker.isHidden {
            datePicker.date = linkExpiryDateField.value
            timePicker.isHidden = true
        }
    }
}

extension EnterSellTicketsDetailsViewController: TimeEntryFieldDelegate {
    func didTap(in timeEntryField: TimeEntryField) {
        timePicker.isHidden = !timePicker.isHidden
        if !timePicker.isHidden {
            timePicker.date = linkExpiryTimeField.value
            datePicker.isHidden = true
        }
    }
}

extension EnterSellTicketsDetailsViewController: AmountTextFieldDelegate {
    func changeAmount(in textField: AmountTextField) {
        viewModel.ethCost = textField.ethCost
        configure(viewModel: viewModel)
    }

    func changeType(in textField: AmountTextField) {
        viewModel.ethCost = textField.ethCost
        configure(viewModel: viewModel)
    }
}
