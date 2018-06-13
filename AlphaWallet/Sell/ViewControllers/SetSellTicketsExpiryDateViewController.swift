// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol SetSellTicketsExpiryDateViewControllerDelegate: class {
    func didSetSellTicketsExpiryDate(ticketHolder: TicketHolder, linkExpiryDate: Date, ethCost: String, in viewController: SetSellTicketsExpiryDateViewController)
    func didPressViewInfo(in viewController: SetSellTicketsExpiryDateViewController)
    func didPressViewContractWebPage(in viewController: SetSellTicketsExpiryDateViewController)
}

class SetSellTicketsExpiryDateViewController: UIViewController {

    let storage: TokensDataStore
    let roundedBackground = RoundedBackground()
    let scrollView = UIScrollView()
    let header = TicketsViewControllerTitleHeader()
    let linkExpiryDateLabel = UILabel()
    let linkExpiryDateField = DateEntryField()
    let linkExpiryTimeLabel = UILabel()
    let linkExpiryTimeField = TimeEntryField()
    let ticketCountLabel = UILabel()
    let perTicketPriceLabel = UILabel()
    let totalEthLabel = UILabel()
    let descriptionLabel = UILabel()
    let noteTitleLabel = UILabel()
    let noteLabel = UILabel()
    let noteBorderView = UIView()
    let ticketView = TicketRowView()
    let nextButton = UIButton(type: .system)
    var datePicker = UIDatePicker()
    var timePicker = UIDatePicker()
    var viewModel: SetSellTicketsExpiryDateViewControllerViewModel!
    var paymentFlow: PaymentFlow
    var ticketHolder: TicketHolder
    var ethCost: String
    weak var delegate: SetSellTicketsExpiryDateViewControllerDelegate?

    init(storage: TokensDataStore, paymentFlow: PaymentFlow, ticketHolder: TicketHolder, ethCost: String) {
        self.storage = storage
        self.paymentFlow = paymentFlow
        self.ticketHolder = ticketHolder
        self.ethCost = ethCost
        super.init(nibName: nil, bundle: nil)

        let button = UIBarButtonItem(image: R.image.verified(), style: .plain, target: self, action: #selector(showContractWebPage))
        button.tintColor = Colors.appGreenContrastBackground
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: R.image.location(), style: .plain, target: self, action: #selector(showInfo)),
            button
        ]

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(scrollView)

        nextButton.setTitle(R.string.localizable.aWalletNextButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)

        ticketView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(ticketView)

        linkExpiryDateLabel.translatesAutoresizingMaskIntoConstraints = false
        linkExpiryTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        ticketCountLabel.translatesAutoresizingMaskIntoConstraints = false
        perTicketPriceLabel.translatesAutoresizingMaskIntoConstraints = false
        totalEthLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        noteTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        noteLabel.translatesAutoresizingMaskIntoConstraints = false

        noteBorderView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(noteBorderView)

        linkExpiryDateField.translatesAutoresizingMaskIntoConstraints = false
        linkExpiryDateField.value = Date.tomorrow
        linkExpiryDateField.delegate = self

        linkExpiryTimeField.translatesAutoresizingMaskIntoConstraints = false
        linkExpiryTimeField.delegate = self

        let col0 = [
            linkExpiryDateLabel,
            .spacer(height: 4),
            linkExpiryDateField,
        ].asStackView(axis: .vertical)
        col0.translatesAutoresizingMaskIntoConstraints = false

        let col1 = [
            linkExpiryTimeLabel,
            .spacer(height: 4),
            linkExpiryTimeField,
        ].asStackView(axis: .vertical)
        col1.translatesAutoresizingMaskIntoConstraints = false

        let choicesStackView = [col0, .spacerWidth(10), col1].asStackView()
        choicesStackView.translatesAutoresizingMaskIntoConstraints = false

        let noteStackView = [
            noteTitleLabel,
            .spacer(height: 4),
            noteLabel,
        ].asStackView(axis: .vertical)
        noteStackView.translatesAutoresizingMaskIntoConstraints = false
        noteBorderView.addSubview(noteStackView)

        datePicker.datePickerMode = .date
        datePicker.minimumDate = Date()
        datePicker.addTarget(self, action: #selector(datePickerValueChanged), for: .valueChanged)
        datePicker.isHidden = true
        if let locale = Config().locale {
            datePicker.locale = Locale(identifier: locale)
        }

        timePicker.datePickerMode = .time
        timePicker.minimumDate = Date.yesterday
        timePicker.addTarget(self, action: #selector(timePickerValueChanged), for: .valueChanged)
        timePicker.isHidden = true
        if let locale = Config().locale {
            timePicker.locale = Locale(identifier: locale)
        }

        let stackView = [
            header,
            ticketView,
            .spacer(height: 18),
            ticketCountLabel,
            perTicketPriceLabel,
            totalEthLabel,
            .spacer(height: 4),
            descriptionLabel,
            .spacer(height: 18),
            choicesStackView,
            datePicker,
            timePicker,
            .spacer(height: 10),
            noteBorderView,
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
            //Strange repositioning of header horizontally while typing without this
            header.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),

            ticketView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ticketView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            linkExpiryDateField.leadingAnchor.constraint(equalTo: ticketView.background.leadingAnchor),
            linkExpiryTimeField.rightAnchor.constraint(equalTo: ticketView.background.rightAnchor),
            linkExpiryDateField.heightAnchor.constraint(equalToConstant: 50),
            linkExpiryDateField.widthAnchor.constraint(equalTo: linkExpiryTimeField.widthAnchor),
            linkExpiryDateField.heightAnchor.constraint(equalTo: linkExpiryTimeField.heightAnchor),

            datePicker.leadingAnchor.constraint(equalTo: ticketView.background.leadingAnchor),
            datePicker.trailingAnchor.constraint(equalTo: ticketView.background.trailingAnchor),

            timePicker.leadingAnchor.constraint(equalTo: ticketView.background.leadingAnchor),
            timePicker.trailingAnchor.constraint(equalTo: ticketView.background.trailingAnchor),

            noteBorderView.leadingAnchor.constraint(equalTo: ticketView.background.leadingAnchor),
            noteBorderView.trailingAnchor.constraint(equalTo: ticketView.background.trailingAnchor),

            noteStackView.leadingAnchor.constraint(equalTo: noteBorderView.leadingAnchor, constant: 10),
            noteStackView.trailingAnchor.constraint(equalTo: noteBorderView.trailingAnchor, constant: -10),
            noteStackView.topAnchor.constraint(equalTo: noteBorderView.topAnchor, constant: 10),
            noteStackView.bottomAnchor.constraint(equalTo: noteBorderView.bottomAnchor, constant: -10),

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
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func nextButtonTapped() {
        let expiryDate = linkExpiryDate()
        guard expiryDate > Date() else {
            UIAlertController.alert(title: "",
                    message: R.string.localizable.aWalletTicketTokenSellLinkExpiryTimeAtLeastNowTitle(),
                    alertButtonTitles: [R.string.localizable.oK()],
                    alertButtonStyles: [.cancel],
                    viewController: self,
                    completion: nil)
            return
        }

        //TODO be good if we check if date chosen is not too far into the future. Example 1 year ahead. Common error?
        delegate?.didSetSellTicketsExpiryDate(ticketHolder: ticketHolder, linkExpiryDate: linkExpiryDate(), ethCost: ethCost, in: self)
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

    @objc func showInfo() {
        delegate?.didPressViewInfo(in: self)
    }

    @objc func showContractWebPage() {
        delegate?.didPressViewContractWebPage(in: self)
    }

    func configure(viewModel: SetSellTicketsExpiryDateViewControllerViewModel) {
        self.viewModel = viewModel
        let contractAddress = XMLHandler().getAddressFromXML(server: Config().server).eip55String
        if !viewModel.token.contract.sameContract(as: contractAddress) {
            let button = UIBarButtonItem(image: R.image.unverified(), style: .plain, target: self, action: #selector(showContractWebPage))
            button.tintColor = Colors.appRed
            navigationItem.rightBarButtonItems = [button]
        }

        view.backgroundColor = viewModel.backgroundColor

        header.configure(title: viewModel.headerTitle)

        ticketView.configure(viewModel: .init())

        linkExpiryDateLabel.textAlignment = .center
        linkExpiryDateLabel.textColor = viewModel.choiceLabelColor
        linkExpiryDateLabel.font = viewModel.choiceLabelFont
        linkExpiryDateLabel.text = viewModel.linkExpiryDateLabelText

        linkExpiryTimeLabel.textAlignment = .center
        linkExpiryTimeLabel.textColor = viewModel.choiceLabelColor
        linkExpiryTimeLabel.font = viewModel.choiceLabelFont
        linkExpiryTimeLabel.text = viewModel.linkExpiryTimeLabelText

        ticketCountLabel.textAlignment = .center
        ticketCountLabel.textColor = viewModel.ticketSaleDetailsLabelColor
        ticketCountLabel.font = viewModel.ticketSaleDetailsLabelFont
        ticketCountLabel.text = viewModel.ticketCountLabelText

        perTicketPriceLabel.textAlignment = .center
        perTicketPriceLabel.textColor = viewModel.ticketSaleDetailsLabelColor
        perTicketPriceLabel.font = viewModel.ticketSaleDetailsLabelFont
        perTicketPriceLabel.text = viewModel.perTicketPriceLabelText

        totalEthLabel.textAlignment = .center
        totalEthLabel.textColor = viewModel.ticketSaleDetailsLabelColor
        totalEthLabel.font = viewModel.ticketSaleDetailsLabelFont
        totalEthLabel.text = viewModel.totalEthLabelText

        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textColor = viewModel.descriptionLabelColor
        descriptionLabel.font = viewModel.descriptionLabelFont
        descriptionLabel.text = viewModel.descriptionLabelText

        noteTitleLabel.textAlignment = .center
        noteTitleLabel.textColor = viewModel.noteTitleLabelColor
        noteTitleLabel.font = viewModel.noteTitleLabelFont
        noteTitleLabel.text = viewModel.noteTitleLabelText

        noteLabel.textAlignment = .center
        noteLabel.numberOfLines = 0
        noteLabel.textColor = viewModel.noteLabelColor
        noteLabel.font = viewModel.noteLabelFont
        noteLabel.text = viewModel.noteLabelText

        noteBorderView.layer.cornerRadius = 20
        noteBorderView.layer.borderColor = viewModel.noteBorderColor.cgColor
        noteBorderView.layer.borderWidth = 1

        ticketView.stateLabel.isHidden = true

        ticketView.ticketCountLabel.text = viewModel.ticketCountString

        ticketView.venueLabel.text = viewModel.venue

        ticketView.dateLabel.text = viewModel.date

        ticketView.cityLabel.text = viewModel.city

        ticketView.categoryLabel.text = viewModel.category

        ticketView.teamsLabel.text = viewModel.teams

        ticketView.matchLabel.text = viewModel.match

        nextButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
		nextButton.backgroundColor = viewModel.buttonBackgroundColor
        nextButton.titleLabel?.font = viewModel.buttonFont
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
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

extension SetSellTicketsExpiryDateViewController: DateEntryFieldDelegate {
    func didTap(in dateEntryField: DateEntryField) {
        datePicker.isHidden = !datePicker.isHidden
        if !datePicker.isHidden {
            datePicker.date = linkExpiryDateField.value
            timePicker.isHidden = true
        }
    }
}

extension SetSellTicketsExpiryDateViewController: TimeEntryFieldDelegate {
    func didTap(in timeEntryField: TimeEntryField) {
        timePicker.isHidden = !timePicker.isHidden
        if !timePicker.isHidden {
            timePicker.date = linkExpiryTimeField.value
            datePicker.isHidden = true
        }
    }
}
