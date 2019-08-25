// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol SetTransferTokensCardExpiryDateViewControllerDelegate: class, CanOpenURL {
    func didPressNext(tokenHolder: TokenHolder, linkExpiryDate: Date, in viewController: SetTransferTokensCardExpiryDateViewController)
    func didPressViewInfo(in viewController: SetTransferTokensCardExpiryDateViewController)
}

class SetTransferTokensCardExpiryDateViewController: UIViewController, TokenVerifiableStatusViewController {
    private let roundedBackground = RoundedBackground()
    private let scrollView = UIScrollView()
    private let header = TokensCardViewControllerTitleHeader()
    private let tokenRowView: TokenRowView & UIView
    private let linkExpiryDateLabel = UILabel()
    private let linkExpiryDateField = DateEntryField()
    private let linkExpiryTimeLabel = UILabel()
    private let linkExpiryTimeField = TimeEntryField()
    private let datePicker = UIDatePicker()
    private let timePicker = UIDatePicker()
    private let descriptionLabel = UILabel()
    private let noteTitleLabel = UILabel()
    private let noteLabel = UILabel()
    private let noteBorderView = UIView()
    private let buttonsBar = ButtonsBar(numberOfButtons: 1)
    private var viewModel: SetTransferTokensCardExpiryDateViewControllerViewModel
    private let tokenHolder: TokenHolder

    var contract: AlphaWallet.Address {
        return viewModel.token.contractAddress
    }
    var server: RPCServer {
        return viewModel.token.server
    }
    let assetDefinitionStore: AssetDefinitionStore
    let paymentFlow: PaymentFlow
    weak var delegate: SetTransferTokensCardExpiryDateViewControllerDelegate?

    init(
            tokenHolder: TokenHolder,
            paymentFlow: PaymentFlow,
            viewModel: SetTransferTokensCardExpiryDateViewControllerViewModel,
            assetDefinitionStore: AssetDefinitionStore
    ) {
        self.tokenHolder = tokenHolder
        self.paymentFlow = paymentFlow
        self.viewModel = viewModel
        self.assetDefinitionStore = assetDefinitionStore

        let tokenType = OpenSeaNonFungibleTokenHandling(token: viewModel.token)
        switch tokenType {
        case .supportedByOpenSea:
            tokenRowView = OpenSeaNonFungibleTokenCardRowView(tokenView: .viewIconified)
        case .notSupportedByOpenSea:
            tokenRowView = TokenCardRowView(server: viewModel.token.server, tokenView: .viewIconified, assetDefinitionStore: assetDefinitionStore)
        }

        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(withTokenScriptFileStatus: nil)

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(scrollView)

        linkExpiryDateLabel.translatesAutoresizingMaskIntoConstraints = false
        linkExpiryTimeLabel.translatesAutoresizingMaskIntoConstraints = false

        tokenRowView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(tokenRowView)

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
        if let locale = Config.getLocale() {
            datePicker.locale = Locale(identifier: locale)
        }

        timePicker.datePickerMode = .time
        timePicker.minimumDate = Date.yesterday
        timePicker.addTarget(self, action: #selector(timePickerValueChanged), for: .valueChanged)
        timePicker.isHidden = true
        if let locale = Config.getLocale() {
            timePicker.locale = Locale(identifier: locale)
        }

        let stackView = [
            header,
            tokenRowView,
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

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = .clear
        roundedBackground.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)

        NSLayoutConstraint.activate([
			header.heightAnchor.constraint(equalToConstant: 90),

            tokenRowView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tokenRowView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            linkExpiryDateField.leadingAnchor.constraint(equalTo: tokenRowView.background.leadingAnchor),
            linkExpiryTimeField.rightAnchor.constraint(equalTo: tokenRowView.background.rightAnchor),
            linkExpiryDateField.heightAnchor.constraint(equalToConstant: 50),
            linkExpiryDateField.widthAnchor.constraint(equalTo: linkExpiryTimeField.widthAnchor),
            linkExpiryDateField.heightAnchor.constraint(equalTo: linkExpiryTimeField.heightAnchor),

            datePicker.leadingAnchor.constraint(equalTo: tokenRowView.background.leadingAnchor),
            datePicker.trailingAnchor.constraint(equalTo: tokenRowView.background.trailingAnchor),

            timePicker.leadingAnchor.constraint(equalTo: tokenRowView.background.leadingAnchor),
            timePicker.trailingAnchor.constraint(equalTo: tokenRowView.background.trailingAnchor),

            noteBorderView.leadingAnchor.constraint(equalTo: tokenRowView.background.leadingAnchor),
            noteBorderView.trailingAnchor.constraint(equalTo: tokenRowView.background.trailingAnchor),

            noteStackView.anchorsConstraint(to: noteBorderView, margin: 10),

            stackView.anchorsConstraint(to: scrollView),

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

            roundedBackground.createConstraintsWithContainer(view: view),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func nextButtonTapped() {
        let expiryDate = linkExpiryDate()
        guard expiryDate > Date() else {
            UIAlertController.alert(title: "",
                    message: R.string.localizable.aWalletTokenTransferLinkExpiryTimeAtLeastNowTitle(),
                    alertButtonTitles: [R.string.localizable.oK()],
                    alertButtonStyles: [.cancel],
                    viewController: self,
                    completion: nil)
            return
        }

        delegate?.didPressNext(tokenHolder: tokenHolder, linkExpiryDate: expiryDate, in: self)
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

    @objc func datePickerValueChanged() {
        linkExpiryDateField.value = datePicker.date
    }

    @objc func timePickerValueChanged() {
        linkExpiryTimeField.value = timePicker.date
    }

    func configure(viewModel newViewModel: SetTransferTokensCardExpiryDateViewControllerViewModel? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }
        updateNavigationRightBarButtons(withTokenScriptFileStatus: tokenScriptFileStatus)

        view.backgroundColor = viewModel.backgroundColor

        header.configure(title: viewModel.headerTitle)

        tokenRowView.configure(tokenHolder: tokenHolder)

        linkExpiryDateLabel.textAlignment = .center
        linkExpiryDateLabel.textColor = viewModel.choiceLabelColor
        linkExpiryDateLabel.font = viewModel.choiceLabelFont
        linkExpiryDateLabel.text = viewModel.linkExpiryDateLabelText

        linkExpiryTimeLabel.textAlignment = .center
        linkExpiryTimeLabel.textColor = viewModel.choiceLabelColor
        linkExpiryTimeLabel.font = viewModel.choiceLabelFont
        linkExpiryTimeLabel.text = viewModel.linkExpiryTimeLabelText

        tokenRowView.stateLabel.isHidden = true

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

        noteBorderView.layer.cornerRadius = viewModel.noteCornerRadius
        noteBorderView.layer.borderColor = viewModel.noteBorderColor.cgColor
        noteBorderView.layer.borderWidth = 1

        buttonsBar.configure()
        let nextButton = buttonsBar.buttons[0]
        nextButton.setTitle(R.string.localizable.aWalletNextButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
    }
}

extension SetTransferTokensCardExpiryDateViewController: VerifiableStatusViewController {
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

extension SetTransferTokensCardExpiryDateViewController: DateEntryFieldDelegate {
    func didTap(in dateEntryField: DateEntryField) {
        datePicker.isHidden = !datePicker.isHidden
        if !datePicker.isHidden {
            datePicker.date = linkExpiryDateField.value
            timePicker.isHidden = true
        }
    }
}

extension SetTransferTokensCardExpiryDateViewController: TimeEntryFieldDelegate {
    func didTap(in timeEntryField: TimeEntryField) {
        timePicker.isHidden = !timePicker.isHidden
        if !timePicker.isHidden {
            timePicker.date = linkExpiryTimeField.value
            datePicker.isHidden = true
        }
    }
}
