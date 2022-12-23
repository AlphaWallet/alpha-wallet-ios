// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

protocol SetTransferTokensCardExpiryDateViewControllerDelegate: AnyObject, CanOpenURL {
    func didPressNext(tokenHolder: TokenHolder, linkExpiryDate: Date, in viewController: SetTransferTokensCardExpiryDateViewController)
    func didPressViewInfo(in viewController: SetTransferTokensCardExpiryDateViewController)
}

class SetTransferTokensCardExpiryDateViewController: UIViewController, TokenVerifiableStatusViewController {
    private let tokenRowView: TokenRowView & UIView
    private let linkExpiryDateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = Configuration.Color.Semantic.alternativeText
        label.font = Fonts.regular(size: 10)

        return label
    }()
    private let linkExpiryDateField = DateEntryField()
    private let linkExpiryTimeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = Configuration.Color.Semantic.alternativeText
        label.font = Fonts.regular(size: 10)

        return label
    }()
    private let linkExpiryTimeField = TimeEntryField()
    private let datePicker: UIDatePicker = .datePicker
    private let timePicker: UIDatePicker = .timePicker
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = Configuration.Color.Semantic.defaultForegroundText
        label.font = Fonts.regular(size: 21)

        return label
    }()
    private let noteTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = Colors.appRed
        label.font = Fonts.semibold(size: 21)

        return label
    }()
    private let noteLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = Colors.appRed
        label.font = Fonts.regular(size: 21)
        label.numberOfLines = 0

        return label
    }()
    private let noteBorderView: UIView = {
        let noteBorderView = UIView()
        noteBorderView.translatesAutoresizingMaskIntoConstraints = false
        noteBorderView.layer.cornerRadius = DataEntry.Metric.CornerRadius.box
        noteBorderView.layer.borderColor = Colors.appRed.cgColor
        noteBorderView.layer.borderWidth = 1

        return noteBorderView
    }()
    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
    private var viewModel: SetTransferTokensCardExpiryDateViewModel
    private let analytics: AnalyticsLogger
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

    private let containerView: ScrollableStackView = {
        let view = ScrollableStackView()
        view.stackView.axis = .vertical
        view.stackView.alignment = .center

        return view
    }()

    init(
        analytics: AnalyticsLogger,
        tokenHolder: TokenHolder,
        paymentFlow: PaymentFlow,
        viewModel: SetTransferTokensCardExpiryDateViewModel,
        assetDefinitionStore: AssetDefinitionStore,
        keystore: Keystore,
        session: WalletSession
    ) {
        self.analytics = analytics
        self.tokenHolder = tokenHolder
        self.paymentFlow = paymentFlow
        self.viewModel = viewModel
        self.assetDefinitionStore = assetDefinitionStore

        let tokenType = OpenSeaBackedNonFungibleTokenHandling(token: viewModel.token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified)
        switch tokenType {
        case .backedByOpenSea:
            tokenRowView = OpenSeaNonFungibleTokenCardRowView(tokenView: .viewIconified)
        case .notBackedByOpenSea:
            tokenRowView = TokenCardRowView(analytics: analytics, server: viewModel.token.server, tokenView: .viewIconified, assetDefinitionStore: assetDefinitionStore, keystore: keystore, wallet: session.account)
        }

        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(withTokenScriptFileStatus: nil)

        tokenRowView.translatesAutoresizingMaskIntoConstraints = false

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

        datePicker.isHidden = true
        timePicker.isHidden = true

        containerView.stackView.addArrangedSubviews([
            .spacer(height: 18),
            tokenRowView,
            .spacer(height: 18),
            descriptionLabel,
            .spacer(height: 18),
            choicesStackView,
            datePicker,
            timePicker,
            .spacer(height: 10),
            noteBorderView,
        ])
        linkExpiryDateField.value = Date.tomorrow
        linkExpiryDateField.delegate = self
        linkExpiryTimeField.delegate = self

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0.0)
        view.addSubview(containerView)
        view.addSubview(footerBar)

        let xOffset: CGFloat = 16

        NSLayoutConstraint.activate([
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

            containerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: xOffset),
            containerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -xOffset),
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            footerBar.anchorsConstraint(to: view),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func nextButtonTapped() {
        let expiryDate = linkExpiryDate()
        guard expiryDate > Date() else {
            UIAlertController.alert(
                    message: R.string.localizable.aWalletTokenTransferLinkExpiryTimeAtLeastNowTitle(),
                    alertButtonTitles: [R.string.localizable.oK()],
                    alertButtonStyles: [.cancel],
                    viewController: self)
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

    @objc private func datePickerValueChanged() {
        linkExpiryDateField.value = datePicker.date
    }

    @objc private func timePickerValueChanged() {
        linkExpiryTimeField.value = timePicker.date
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        timePicker.addTarget(self, action: #selector(timePickerValueChanged), for: .valueChanged)
        datePicker.addTarget(self, action: #selector(datePickerValueChanged), for: .valueChanged)
        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        buttonsBar.configure()
        let nextButton = buttonsBar.buttons[0]
        nextButton.setTitle(R.string.localizable.aWalletNextButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
    }

    func configure(viewModel newViewModel: SetTransferTokensCardExpiryDateViewModel? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }
        updateNavigationRightBarButtons(withTokenScriptFileStatus: tokenScriptFileStatus)

        navigationItem.title = viewModel.headerTitle
        tokenRowView.configure(tokenHolder: tokenHolder)

        tokenRowView.stateLabel.isHidden = true
        linkExpiryDateLabel.text = viewModel.linkExpiryDateLabelText
        linkExpiryTimeLabel.text = viewModel.linkExpiryTimeLabelText
        descriptionLabel.text = viewModel.descriptionLabelText
        noteTitleLabel.text = viewModel.noteTitleLabelText
        noteLabel.text = viewModel.noteLabelText
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
