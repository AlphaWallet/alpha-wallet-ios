// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletCore
import AlphaWalletFoundation

protocol SetSellTokensCardExpiryDateViewControllerDelegate: AnyObject, CanOpenURL {
    func didSetSellTokensExpiryDate(tokenHolder: TokenHolder, linkExpiryDate: Date, ethCost: Double, in viewController: SetSellTokensCardExpiryDateViewController)
    func didPressViewInfo(in viewController: SetSellTokensCardExpiryDateViewController)
}

class SetSellTokensCardExpiryDateViewController: UIViewController, TokenVerifiableStatusViewController {
    private let linkExpiryDateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = Configuration.Color.Semantic.defaultForegroundText
        label.font = Fonts.regular(size: 10)

        return label
    }()
    private let linkExpiryDateField = DateEntryField()
    private let linkExpiryTimeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = Configuration.Color.Semantic.defaultForegroundText
        label.font = Fonts.regular(size: 10)

        return label
    }()
    private let linkExpiryTimeField = TimeEntryField()
    private let tokenCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = Configuration.Color.Semantic.defaultSubtitleText
        label.font = Fonts.semibold(size: 21)

        return label
    }()

    private let perTokenPriceLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = Configuration.Color.Semantic.defaultSubtitleText
        label.font = Fonts.semibold(size: 21)

        return label
    }()
    private let totalEthLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = Configuration.Color.Semantic.defaultSubtitleText
        label.font = Fonts.semibold(size: 21)

        return label
    }()
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = Configuration.Color.Semantic.defaultSubtitleText
        label.font = Fonts.semibold(size: 21)
        label.numberOfLines = 0

        return label
    }()
    private let noteTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = Configuration.Color.Semantic.defaultNote
        label.font = Fonts.semibold(size: 21)

        return label
    }()
    private let noteLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = Configuration.Color.Semantic.defaultNote
        label.font = Fonts.semibold(size: 21)
        label.numberOfLines = 0

        return label
    }()
    private let noteBorderView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = DataEntry.Metric.CornerRadius.box
        view.layer.borderColor = Configuration.Color.Semantic.defaultNote.cgColor
        view.layer.borderWidth = 1

        return view
    }()
    private let tokenRowView: TokenRowView & UIView
    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
    private let datePicker = UIDatePicker.datePicker
    private let timePicker = UIDatePicker.timePicker
    private (set) var viewModel: SetSellTokensCardExpiryDateViewModel
    private let containerView: ScrollableStackView = {
        let view = ScrollableStackView()
        view.stackView.axis = .vertical
        view.stackView.alignment = .center

        return view
    }()
    var contract: AlphaWallet.Address {
        return viewModel.token.contractAddress
    }
    var server: RPCServer {
        return viewModel.token.server
    }
    let assetDefinitionStore: AssetDefinitionStore

    weak var delegate: SetSellTokensCardExpiryDateViewControllerDelegate?

    private var linkExpiryDate: Date {
        let hour = NSCalendar.current.component(.hour, from: linkExpiryTimeField.value)
        let minutes = NSCalendar.current.component(.minute, from: linkExpiryTimeField.value)
        let seconds = NSCalendar.current.component(.second, from: linkExpiryTimeField.value)
        if let date = NSCalendar.current.date(bySettingHour: hour, minute: minutes, second: seconds, of: linkExpiryDateField.value) {
            return date
        } else {
            return Date()
        }
    }

    init(viewModel: SetSellTokensCardExpiryDateViewModel,
         assetDefinitionStore: AssetDefinitionStore,
         session: WalletSession) {

        self.viewModel = viewModel
        self.assetDefinitionStore = assetDefinitionStore

        let tokenType = OpenSeaBackedNonFungibleTokenHandling(token: viewModel.token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified)
        switch tokenType {
        case .backedByOpenSea:
            tokenRowView = OpenSeaNonFungibleTokenCardRowView(tokenView: .viewIconified)
        case .notBackedByOpenSea:
            tokenRowView = TokenCardRowView(server: viewModel.token.server, tokenView: .viewIconified, assetDefinitionStore: assetDefinitionStore, wallet: session.account)
        }

        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(withTokenScriptFileStatus: nil)

        view.addSubview(containerView)
        tokenRowView.translatesAutoresizingMaskIntoConstraints = false

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

        containerView.stackView.addArrangedSubviews([
            .spacer(height: 18),
            tokenRowView,
            .spacer(height: 18),
            tokenCountLabel,
            perTokenPriceLabel,
            totalEthLabel,
            .spacer(height: 4),
            descriptionLabel,
            .spacer(height: 18),
            choicesStackView,
            datePicker,
            timePicker,
            .spacer(height: 10),
            noteBorderView,
        ])

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

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func nextButtonTapped() {
        let expiryDate = linkExpiryDate
        guard expiryDate > Date() else {
            UIAlertController.alert(title: "",
                    message: R.string.localizable.aWalletTokenSellLinkExpiryTimeAtLeastNowTitle(),
                    alertButtonTitles: [R.string.localizable.oK()],
                    alertButtonStyles: [.cancel],
                    viewController: self,
                    completion: nil)
            return
        }

        //TODO be good if we check if date chosen is not too far into the future. Example 1 year ahead. Common error?
        delegate?.didSetSellTokensExpiryDate(tokenHolder: viewModel.tokenHolder, linkExpiryDate: expiryDate, ethCost: viewModel.ethCost, in: self)
    }

    func configure(viewModel newViewModel: SetSellTokensCardExpiryDateViewModel? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }
        updateNavigationRightBarButtons(withTokenScriptFileStatus: tokenScriptFileStatus)

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        navigationItem.title = viewModel.headerTitle

        tokenRowView.configure(tokenHolder: viewModel.tokenHolder)

        linkExpiryDateLabel.text = viewModel.linkExpiryDateLabelText
        linkExpiryTimeLabel.text = viewModel.linkExpiryTimeLabelText
        tokenCountLabel.text = viewModel.tokenCountLabelText
        perTokenPriceLabel.text = viewModel.perTokenPriceLabelText
        totalEthLabel.text = viewModel.totalEthLabelText
        descriptionLabel.text = viewModel.descriptionLabelText
        noteTitleLabel.text = viewModel.noteTitleLabelText
        noteLabel.text = viewModel.noteLabelText

        tokenRowView.stateLabel.isHidden = true
    }

    @objc private func datePickerValueChanged() {
        linkExpiryDateField.value = datePicker.date
    }

    @objc private func timePickerValueChanged() {
        linkExpiryTimeField.value = timePicker.date
    }
}

extension SetSellTokensCardExpiryDateViewController: VerifiableStatusViewController {
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

extension SetSellTokensCardExpiryDateViewController: DateEntryFieldDelegate {
    func didTap(in dateEntryField: DateEntryField) {
        datePicker.isHidden = !datePicker.isHidden
        if !datePicker.isHidden {
            datePicker.date = linkExpiryDateField.value
            timePicker.isHidden = true
        }
    }
}

extension SetSellTokensCardExpiryDateViewController: TimeEntryFieldDelegate {
    func didTap(in timeEntryField: TimeEntryField) {
        timePicker.isHidden = !timePicker.isHidden
        if !timePicker.isHidden {
            timePicker.date = linkExpiryTimeField.value
            datePicker.isHidden = true
        }
    }
}

extension UIDatePicker {
    var textColor: UIColor? {
        get { return value(forKeyPath: "textColor") as? UIColor }
        set { setValue(newValue, forKeyPath: "textColor") }
    }

    static var timePicker: UIDatePicker {
        let picker = UIDatePicker()
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.datePickerMode = .time
        picker.minimumDate = Date.yesterday
        picker.isHidden = true
        if let locale = Config.getLocale() {
            picker.locale = Locale(identifier: locale)
        }
        picker.textColor = Configuration.Color.Semantic.defaultInverseText

        return picker
    }

    static var datePicker: UIDatePicker {
        let datePicker = UIDatePicker()
        datePicker.translatesAutoresizingMaskIntoConstraints = false

        datePicker.datePickerMode = .date
        datePicker.minimumDate = Date()
        datePicker.isHidden = true
        if let locale = Config.getLocale() {
            datePicker.locale = Locale(identifier: locale)
        }
        datePicker.textColor = Configuration.Color.Semantic.defaultInverseText

        return datePicker
    }
}
