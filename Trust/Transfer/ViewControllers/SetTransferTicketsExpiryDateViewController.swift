// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol SetTransferTicketsExpiryDateViewControllerDelegate: class {
    func didPressNext(ticketHolder: TicketHolder, linkExpiryDate: Date, in viewController: SetTransferTicketsExpiryDateViewController)
    func didPressViewInfo(in viewController: SetTransferTicketsExpiryDateViewController)
}

class SetTransferTicketsExpiryDateViewController: UIViewController {

    let roundedBackground = RoundedBackground()
    let scrollView = UIScrollView()
    let header = TicketsViewControllerTitleHeader()
    let ticketView = TicketRowView()
    let linkExpiryDateLabel = UILabel()
    let linkExpiryDateField = DateEntryField()
    let linkExpiryTimeLabel = UILabel()
    let linkExpiryTimeField = TimeEntryField()
    var datePicker = UIDatePicker()
    var timePicker = UIDatePicker()
    let descriptionLabel = UILabel()
    let noteTitleLabel = UILabel()
    let noteLabel = UILabel()
    let noteBorderView = UIView()
    let nextButton = UIButton(type: .system)
    var viewModel: SetTransferTicketsExpiryDateViewControllerViewModel!
    var ticketHolder: TicketHolder
    var paymentFlow: PaymentFlow
    weak var delegate: SetTransferTicketsExpiryDateViewControllerDelegate?

    init(ticketHolder: TicketHolder, paymentFlow: PaymentFlow) {
        self.ticketHolder = ticketHolder
        self.paymentFlow = paymentFlow
        super.init(nibName: nil, bundle: nil)

        navigationItem.rightBarButtonItem = UIBarButtonItem(image: R.image.location(), style: .plain, target: self, action: #selector(showInfo))

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(scrollView)

        linkExpiryDateLabel.translatesAutoresizingMaskIntoConstraints = false
        linkExpiryTimeLabel.translatesAutoresizingMaskIntoConstraints = false

        nextButton.setTitle(R.string.localizable.aWalletNextButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)

        ticketView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(ticketView)

        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        noteTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        noteLabel.translatesAutoresizingMaskIntoConstraints = false

        noteBorderView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(noteBorderView)

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

        timePicker.datePickerMode = .time
        timePicker.minimumDate = Date.yesterday
        timePicker.addTarget(self, action: #selector(timePickerValueChanged), for: .valueChanged)
        timePicker.isHidden = true

        let stackView = [
            header,
            ticketView,
            .spacer(height: 18),
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

        linkExpiryDateField.translatesAutoresizingMaskIntoConstraints = false
        linkExpiryDateField.value = Date.tomorrow
        linkExpiryDateField.delegate = self

        linkExpiryTimeField.translatesAutoresizingMaskIntoConstraints = false
        linkExpiryTimeField.delegate = self

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
                    message: R.string.localizable.aWalletTicketTokenTransferLinkExpiryTimeAtLeastNowTitle(),
                    alertButtonTitles: [R.string.localizable.oK()],
                    alertButtonStyles: [.cancel],
                    viewController: self,
                    completion: nil)
            return
        }

        delegate?.didPressNext(ticketHolder: ticketHolder, linkExpiryDate: expiryDate, in: self)
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

    func configure(viewModel: SetTransferTicketsExpiryDateViewControllerViewModel) {
        self.viewModel = viewModel

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

        ticketView.stateLabel.isHidden = true

        ticketView.ticketCountLabel.text = viewModel.ticketCount

        ticketView.titleLabel.text = viewModel.title

        ticketView.venueLabel.text = viewModel.venue

        ticketView.dateLabel.text = viewModel.date

        ticketView.seatRangeLabel.text = viewModel.seatRange

        ticketView.cityLabel.text = viewModel.city

        ticketView.categoryLabel.text = viewModel.category

        ticketView.teamsLabel.text = viewModel.teams

        ticketView.matchLabel.text = viewModel.match

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

        nextButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
		nextButton.backgroundColor = viewModel.buttonBackgroundColor
        nextButton.titleLabel?.font = viewModel.buttonFont
    }
}

extension SetTransferTicketsExpiryDateViewController: DateEntryFieldDelegate {
    func didTap(in dateEntryField: DateEntryField) {
        datePicker.isHidden = !datePicker.isHidden
        if !datePicker.isHidden {
            datePicker.date = linkExpiryDateField.value
            timePicker.isHidden = true
        }
    }
}

extension SetTransferTicketsExpiryDateViewController: TimeEntryFieldDelegate {
    func didTap(in timeEntryField: TimeEntryField) {
        timePicker.isHidden = !timePicker.isHidden
        if !timePicker.isHidden {
            timePicker.date = linkExpiryTimeField.value
            datePicker.isHidden = true
        }
    }
}
