// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Combine
import AlphaWalletFoundation
import AlphaWalletTrustWalletCoreExtensions

protocol ImportWalletViewControllerDelegate: AnyObject {
    func didImportAccount(account: Wallet, in viewController: ImportWalletViewController)
    func openQRCode(in controller: ImportWalletViewController)
}

// swiftlint:disable type_body_length
class ImportWalletViewController: UIViewController {
    private static let mnemonicSuggestionsBarHeight: CGFloat = ScreenChecker().isNarrowScreen ? 40 : 60

    private let keystore: Keystore
    private let analytics: AnalyticsLogger
    private let domainResolutionService: DomainNameResolutionServiceType
    private let viewModel = ImportWalletViewModel()

    private lazy var containerView: ScrollableStackView = {
        let containerView = ScrollableStackView()
        containerView.stackView.axis = .vertical
        containerView.scrollView.showsVerticalScrollIndicator = false

        return containerView
    }()

    private let tabBar: ScrollableSegmentedControl = {
        let cellConfiguration = Style.ScrollableSegmentedControlCell.configuration
        let controlConfiguration = Style.ScrollableSegmentedControl.configuration
        let cells = ImportWalletViewModel.segmentedControlTitles.map { title in
            ScrollableSegmentedControlCell(frame: .zero, title: title, configuration: cellConfiguration)
        }
        let control = ScrollableSegmentedControl(cells: cells, configuration: controlConfiguration)
        control.setSelection(cellIndex: 0)

        return control
    }()

    private let mnemonicCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .right
        label.font = Configuration.Font.label
        label.textColor = Configuration.Color.Semantic.defaultSubtitleText

        return label
    }()

    private lazy var mnemonicTextView: TextView = {
        let textView = TextView.defaultTextView
        textView.delegate = self
        textView.inputAccessoryButtonType = .done
        textView.returnKeyType = .done

        return textView
    }()

    private lazy var keystoreJSONTextView: TextView = {
        let textView = TextView.defaultTextView
        textView.delegate = self
        textView.inputAccessoryButtonType = .next
        textView.returnKeyType = .next

        return textView
    }()

    private lazy var passwordTextField: TextField = {
        let textField = TextField.buildPasswordTextField()
        textField.delegate = self
        textField.returnKeyType = .done
        textField.inputAccessoryButtonType = .done

        return textField
    }()

    private lazy var privateKeyTextView: TextView = {
        let textView = TextView.defaultTextView
        textView.delegate = self
        textView.inputAccessoryButtonType = .done
        textView.returnKeyType = .done

        return textView
    }()
    lazy var watchAddressTextField: AddressTextField = {
        let textField = AddressTextField(server: RPCServer.forResolvingDomainNames, domainResolutionService: domainResolutionService)
        textField.inputAccessoryButtonType = .done
        textField.delegate = self
        textField.returnKeyType = .done

        return textField
    }()

    private lazy var mnemonicControlsLayout: UIStackView = {
        let row2 = [mnemonicTextView.statusLabel, mnemonicCountLabel].asStackView()
        row2.translatesAutoresizingMaskIntoConstraints = false
        let mnemonicControlsStackView = [
            mnemonicTextView.label,
            .spacer(height: DataEntry.Metric.TextField.Default.spaceFromTextFieldToStatusLabel),
            [.spacerWidth(DataEntry.Metric.shadowRadius), mnemonicTextView, .spacerWidth(DataEntry.Metric.shadowRadius)].asStackView(axis: .horizontal),
            .spacer(height: DataEntry.Metric.TextField.Default.spaceFromTextFieldToStatusLabel),
            row2
        ].asStackView(axis: .vertical, distribution: .fill)
        mnemonicControlsStackView.translatesAutoresizingMaskIntoConstraints = false

        return mnemonicControlsStackView
    }()
    private lazy var keystoreJSONControlsLayout: UIStackView = [
        keystoreJSONTextView.defaultLayout(),
        passwordTextField.defaultLayout(),
    ].asStackView(axis: .vertical)

    private lazy var privateKeyControlsLayout: UIView = privateKeyTextView.defaultLayout()
    private lazy var watchControlsLayout: UIView = watchAddressTextField.defaultLayout(edgeInsets: .zero)
    private var cancellable = Set<AnyCancellable>()

    private lazy var importSeedDescriptionLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.isHidden = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = Configuration.Color.Semantic.defaultSubtitleText
        return label
    }()

    private var mnemonicSuggestions: [String] = .init() {
        didSet {
            mnemonicSuggestionsCollectionView.reloadData()
        }
    }

    private lazy var mnemonicSuggestionsCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.estimatedItemSize = CGSize(width: 140, height: ScreenChecker().isNarrowScreen ? 30 : 40)
        layout.scrollDirection = .horizontal

        let frame: CGRect = .init(x: 0, y: 0, width: 0, height: ImportWalletViewController.mnemonicSuggestionsBarHeight)
        let cv = UICollectionView(frame: frame, collectionViewLayout: layout)
        cv.contentInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        cv.register(SeedPhraseSuggestionViewCell.self)
        cv.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        cv.showsHorizontalScrollIndicator = false
        cv.delegate = self

        return cv
    }()

    private var mnemonicInput: [String] {
        mnemonicInputString.split(separator: " ").map { String($0) }
    }

    private var mnemonicInputString: String {
        mnemonicTextView.value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private let buttonsBar = VerticalButtonsBar(numberOfButtons: 2)

    private var importButton: UIButton {
        return buttonsBar.buttons[0]
    }

    private var importKeystoreJsonFromCloudButton: UIButton {
        return buttonsBar.buttons[1]
    }

    weak var delegate: ImportWalletViewControllerDelegate?

    init(keystore: Keystore, analytics: AnalyticsLogger, domainResolutionService: DomainNameResolutionServiceType) {
        self.keystore = keystore
        self.analytics = analytics
        self.domainResolutionService = domainResolutionService

        super.init(nibName: nil, bundle: nil)

        navigationItem.title = viewModel.title

        containerView.stackView.addArrangedSubviews([
            .spacer(height: ScreenChecker().isNarrowScreen ? 10 : 30),
            mnemonicControlsLayout,
            keystoreJSONControlsLayout,
            privateKeyControlsLayout,
            watchControlsLayout,
        ])

        buttonsBar.hideButtonInStack(button: importKeystoreJsonFromCloudButton)

        view.addSubview(tabBar)
        view.addSubview(containerView)
        view.addSubview(importSeedDescriptionLabel)

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0)
        view.addSubview(footerBar)

        let heightThatFitsPrivateKeyNicely = ScreenChecker.size(big: 100, medium: 100, small: 80)

        let bottomConstraint = footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        bottomConstraint.constant = -UIApplication.shared.bottomSafeAreaHeight

        let labelButtonInset: CGFloat = ScreenChecker.size(big: 20, medium: 20, small: 10)

        NSLayoutConstraint.activate([
            mnemonicTextView.heightAnchor.constraint(equalToConstant: heightThatFitsPrivateKeyNicely),
            keystoreJSONTextView.heightAnchor.constraint(equalToConstant: heightThatFitsPrivateKeyNicely),
            privateKeyTextView.heightAnchor.constraint(equalToConstant: heightThatFitsPrivateKeyNicely),

            tabBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: DataEntry.Metric.TabBar.height),

            importSeedDescriptionLabel.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor, constant: 30),
            importSeedDescriptionLabel.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor, constant: -30),
            importSeedDescriptionLabel.bottomAnchor.constraint(equalTo: footerBar.topAnchor, constant: -labelButtonInset),

            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DataEntry.Metric.Container.xMargin),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DataEntry.Metric.Container.xMargin),
            containerView.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            containerView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            footerBar.anchorsConstraint(to: view)
        ])

        configure()
        showMnemonicControlsOnly()

        navigationItem.rightBarButtonItem = UIBarButtonItem.qrCodeBarButton(self, selector: #selector(openReader))

        if UserDefaults.standardOrForTests.bool(forKey: "FASTLANE_SNAPSHOT") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.demo()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tabBar.addTarget(self, action: #selector(didTapSegment), for: .touchUpInside)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //Because we want the filter to look like it's a part of the navigation bar
        navigationController?.navigationBar.shadowImage = UIImage()
    }

    @objc func didTapSegment(_ control: ScrollableSegmentedControl) {
        showCorrectTab()
    }

    private func showCorrectTab() {
        guard let tab = viewModel.convertSegmentedControlSelectionToFilter(tabBar.selectedSegment) else { return }
        switch tab {
        case .mnemonic:
            showMnemonicControlsOnly()
        case .keystore:
            showKeystoreControlsOnly()
        case .privateKey:
            showPrivateKeyControlsOnly()
        case .watch:
            showWatchControlsOnly()
        }
    }

    func showWatchTab() {
        tabBar.setSelection(cellIndex: Int(ImportWalletTab.watch.selectionIndex))
        showCorrectTab()
    }

    private func configure() {
        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        mnemonicTextView.label.text = viewModel.mnemonicLabel
        mnemonicCountLabel.text = "\(mnemonicInput.count)"

        mnemonicSuggestionsCollectionView.dataSource = self

        keystoreJSONTextView.label.text = viewModel.keystoreJSONLabel
        passwordTextField.label.text = viewModel.passwordLabel
        privateKeyTextView.label.text = viewModel.privateKeyLabel
        watchAddressTextField.label.text = viewModel.watchAddressLabel

        importKeystoreJsonFromCloudButton.addTarget(self, action: #selector(importOptions), for: .touchUpInside)
        importKeystoreJsonFromCloudButton.setTitle(R.string.localizable.importWalletImportFromCloudTitle(), for: .normal)
        importKeystoreJsonFromCloudButton.titleLabel?.font = viewModel.importKeystoreJsonButtonFont
        importKeystoreJsonFromCloudButton.titleLabel?.adjustsFontSizeToFitWidth = true

        importSeedDescriptionLabel.attributedText = viewModel.importSeedAttributedText

        importButton.addTarget(self, action: #selector(importWallet), for: .touchUpInside)
        configureImportButtonTitle(R.string.localizable.importWalletImportButtonTitle())
    }

    private func configureImportButtonTitle(_ title: String) {
        importButton.setTitle(title, for: .normal)
    }

    private func didImport(account: Wallet) {
        delegate?.didImportAccount(account: account, in: self)
    }

    ///Returns true only if valid
    private func validate() -> Bool {
        guard let tab = viewModel.convertSegmentedControlSelectionToFilter(tabBar.selectedSegment) else { return false }
        switch tab {
        case .mnemonic:
            return validateMnemonic()
        case .keystore:
            return validateKeystore()
        case .privateKey:
            return validatePrivateKey()
        case .watch:
            return validateWatch()
        }
    }

    ///Returns true only if valid
    private func validateMnemonic() -> Bool {
        mnemonicTextView.errorState = .none
        var msg: String
        if Features.current.isAvailable(.is24SeedWordPhraseAllowed) {
            msg = R.string.localizable.importWalletImportInvalidMnemonicCount24()
        } else {
            msg = R.string.localizable.importWalletImportInvalidMnemonicCount12()
        }
        if let validationError = MnemonicLengthValidator(message: msg).isValid(value: mnemonicInputString) {
            mnemonicTextView.errorState = .error(validationError.msg)

            return false
        }
        if let validationError = MnemonicInWordListValidator(msg: R.string.localizable.importWalletImportInvalidMnemonic()).isValid(value: mnemonicInputString) {
            mnemonicTextView.errorState = .error(validationError.msg)
            return false
        }
        return true
    }

    ///Returns true only if valid
    private func validateKeystore() -> Bool {
        keystoreJSONTextView.errorState = .none
        if keystoreJSONTextView.value.isEmpty {
            keystoreJSONTextView.errorState = .error(R.string.localizable.warningFieldRequired())
            return false
        }
        if passwordTextField.value.isEmpty {
            keystoreJSONTextView.errorState = .error(R.string.localizable.warningFieldRequired())
            return false
        }
        return true
    }

    ///Returns true only if valid
    private func validatePrivateKey() -> Bool {
        privateKeyTextView.errorState = .none
        if let validationError = PrivateKeyValidator(msg: R.string.localizable.importWalletImportInvalidPrivateKey()).isValid(value: privateKeyTextView.value.trimmed) {
            privateKeyTextView.errorState = .error(validationError.msg)
            return false
        }
        return true
    }

    ///Returns true only if valid
    private func validateWatch() -> Bool {
        watchAddressTextField.errorState = .none
        if let validationError = EthereumAddressValidator(msg: R.string.localizable.importWalletImportInvalidAddress()).isValid(value: watchAddressTextField.value) {
            watchAddressTextField.errorState = .error(validationError.msg)
            return false
        }
        return true
    }

    @objc func importWallet() {
        guard validate() else { return }

        switch viewModel.convertSegmentedControlSelectionToFilter(tabBar.selectedSegment) {
        case .mnemonic:
            displayLoading(text: R.string.localizable.importWalletImportingIndicatorLabelTitle(), animated: false)
            keystore.importWallet(mnemonic: mnemonicInput, passphrase: "")
                .sink(receiveCompletion: { result in
                    self.hideLoading(animated: false)

                    if case .failure(let error) = result {
                        self.displayError(error: error)
                    }
                }, receiveValue: { wallet in
                    self.didImport(account: wallet)
                }).store(in: &cancellable)
        case .keystore:
            displayLoading(text: R.string.localizable.importWalletImportingIndicatorLabelTitle(), animated: false)
            keystore.importWallet(json: keystoreJSONTextView.value.trimmed, password: passwordTextField.value.trimmed)
                .sink(receiveCompletion: { result in
                    self.hideLoading(animated: false)

                    if case .failure(let error) = result {
                        self.displayError(error: error)
                    }
                }, receiveValue: { wallet in
                    self.didImport(account: wallet)
                }).store(in: &cancellable)
        case .privateKey:
            guard let data = Data(hexString: privateKeyTextView.value.trimmed.drop0x) else {
                privateKeyTextView.errorState = .error(R.string.localizable.importWalletImportInvalidPrivateKey())
                return
            }
            privateKeyTextView.errorState = .none

            displayLoading(text: R.string.localizable.importWalletImportingIndicatorLabelTitle(), animated: false)
            keystore.importWallet(privateKey: data)
                .sink(receiveCompletion: { result in
                    self.hideLoading(animated: false)

                    if case .failure(let error) = result {
                        self.displayError(error: error)
                    }
                }, receiveValue: { wallet in
                    self.didImport(account: wallet)
                }).store(in: &cancellable)
        case .watch:
            guard let address = AlphaWallet.Address(string: watchAddressTextField.value.trimmed) else {
                watchAddressTextField.errorState = .error(R.string.localizable.importWalletImportInvalidAddress())
                return
            }

            displayLoading(text: R.string.localizable.importWalletImportingIndicatorLabelTitle(), animated: false)
            keystore.watchWallet(address: address)
                .sink(receiveCompletion: { result in
                    self.hideLoading(animated: false)

                    if case .failure(let error) = result {
                        self.displayError(error: error)
                    }
                }, receiveValue: { wallet in
                    self.didImport(account: wallet)
                }).store(in: &cancellable)
        case .none:
            break
        }
    }

    @objc func demo() {
        //Used for taking screenshots to the App Store by snapshot
        let demoWallet = Wallet(address: AlphaWallet.Address(string: "0xD663bE6b87A992C5245F054D32C7f5e99f5aCc47")!, origin: .watch)
        delegate?.didImportAccount(account: demoWallet, in: self)
    }

    @objc func importOptions(sender: UIButton) {
        let alertController = UIAlertController(
            title: R.string.localizable.importWalletImportAlertSheetTitle(),
            message: .none,
            preferredStyle: .actionSheet)
        alertController.popoverPresentationController?.sourceView = sender
        alertController.popoverPresentationController?.sourceRect = sender.bounds
        alertController.addAction(UIAlertAction(
            title: R.string.localizable.importWalletImportAlertSheetOptionTitle(),
            style: .default
        ) {  [weak self] _ in
            self?.showDocumentPicker()
        })
        alertController.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in })
        present(alertController, animated: true)
    }

    func showDocumentPicker() {
        let types = ["public.text", "public.content", "public.item", "public.data"]
        let controller = UIDocumentPickerViewController(documentTypes: types, in: .import)
        controller.delegate = self

        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            controller.modalPresentationStyle = .formSheet
        case .phone:
            controller.makePresentationFullScreenForiOS13Migration()
        //NOTE: allow to support version xCode 11.7 and xCode 12
        default:
            controller.makePresentationFullScreenForiOS13Migration()
        }

        present(controller, animated: true)
    }

    @objc private func openReader() {
        delegate?.openQRCode(in: self)
    }

    func set(tabSelection selection: ImportWalletTab) {
        tabBar.setSelection(cellIndex: Int(selection.selectionIndex))
    }

    func setValueForCurrentField(string: String) {
        switch viewModel.convertSegmentedControlSelectionToFilter(tabBar.selectedSegment) {
        case .mnemonic:
            mnemonicTextView.value = string
        case .keystore:
            keystoreJSONTextView.value = string
        case .privateKey:
            privateKeyTextView.value = string
        case .watch:
            watchAddressTextField.value = string
        case .none:
            break
        }

        showCorrectTab()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func showMnemonicControlsOnly() {
        mnemonicControlsLayout.isHidden = false
        keystoreJSONControlsLayout.isHidden = true
        privateKeyControlsLayout.isHidden = true
        watchControlsLayout.isHidden = true
        configureImportButtonTitle(R.string.localizable.importWalletImportButtonTitle())
        buttonsBar.hideButtonInStack(button: importKeystoreJsonFromCloudButton)
        importSeedDescriptionLabel.isHidden = false
        importButton.isEnabled = !mnemonicTextView.value.isEmpty
        mnemonicTextView.textView.inputAccessoryView = mnemonicSuggestionsCollectionView
        mnemonicTextView.textView.reloadInputViews()
    }

    private func showKeystoreControlsOnly() {
        mnemonicControlsLayout.isHidden = true
        keystoreJSONControlsLayout.isHidden = false
        privateKeyControlsLayout.isHidden = true
        watchControlsLayout.isHidden = true
        configureImportButtonTitle(R.string.localizable.importWalletImportButtonTitle())
        // importKeystoreJsonFromCloudButton.isHidden = false
        buttonsBar.showButtonInStack(button: importKeystoreJsonFromCloudButton, position: 1)
        importSeedDescriptionLabel.isHidden = true
        importButton.isEnabled = !keystoreJSONTextView.value.isEmpty && !passwordTextField.value.isEmpty
        mnemonicTextView.textView.inputAccessoryView = nil
        mnemonicTextView.textView.reloadInputViews()
    }

    private func showPrivateKeyControlsOnly() {
        mnemonicControlsLayout.isHidden = true
        keystoreJSONControlsLayout.isHidden = true
        privateKeyControlsLayout.isHidden = false
        watchControlsLayout.isHidden = true
        configureImportButtonTitle(R.string.localizable.importWalletImportButtonTitle())
        buttonsBar.hideButtonInStack(button: importKeystoreJsonFromCloudButton)
        importSeedDescriptionLabel.isHidden = true
        importButton.isEnabled = !privateKeyTextView.value.isEmpty
        mnemonicTextView.textView.inputAccessoryView = nil
        mnemonicTextView.textView.reloadInputViews()
    }

    private func showWatchControlsOnly() {
        mnemonicControlsLayout.isHidden = true
        keystoreJSONControlsLayout.isHidden = true
        privateKeyControlsLayout.isHidden = true
        watchControlsLayout.isHidden = false
        configureImportButtonTitle(R.string.localizable.walletWatchButtonTitle())
        buttonsBar.hideButtonInStack(button: importKeystoreJsonFromCloudButton)
        importSeedDescriptionLabel.isHidden = true
        importButton.isEnabled = !watchAddressTextField.value.isEmpty
        mnemonicTextView.textView.inputAccessoryView = nil
        mnemonicTextView.textView.reloadInputViews()
    }

    private func moveFocusToTextEntryField(after textInput: UIView) {
        switch textInput {
        case mnemonicTextView:
            view.endEditing(true)
        case keystoreJSONTextView:
            passwordTextField.becomeFirstResponder()
        case passwordTextField:
            view.endEditing(true)
        case privateKeyTextView:
            view.endEditing(true)
        case watchAddressTextField:
            view.endEditing(true)
        default:
            break
        }
    }
}
// swiftlint:enable type_body_length

extension ImportWalletViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        guard controller.documentPickerMode == UIDocumentPickerMode.import else { return }
        let text = try? String(contentsOfFile: url.path)
        if let text = text {
            keystoreJSONTextView.value = text
        }
    }
}

extension ImportWalletViewController: TextFieldDelegate {

    func didScanQRCode(_ result: String) {
        setValueForCurrentField(string: result)
    }

    func shouldReturn(in textField: TextField) -> Bool {
        moveFocusToTextEntryField(after: textField)
        return false
    }

    func doneButtonTapped(for textField: TextField) {
        view.endEditing(true)
    }

    func nextButtonTapped(for textField: TextField) {
        moveFocusToTextEntryField(after: textField)
    }

    func shouldChangeCharacters(inRange range: NSRange, replacementString string: String, for textField: TextField) -> Bool {
        //Just easier to dispatch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.showCorrectTab()
        }
        return true
    }
}

extension ImportWalletViewController: TextViewDelegate {

    func didPaste(in textView: TextView) {
        view.endEditing(true)
        showCorrectTab()
    }

    func shouldReturn(in textView: TextView) -> Bool {
        moveFocusToTextEntryField(after: textView)
        return false
    }

    func doneButtonTapped(for textView: TextView) {
        view.endEditing(true)
    }

    func nextButtonTapped(for textView: TextView) {
        moveFocusToTextEntryField(after: textView)
    }

    func didChange(inTextView textView: TextView) {
        showCorrectTab()
        guard textView == mnemonicTextView else { return }
        mnemonicCountLabel.text = "\(mnemonicInput.count)"
        if let lastMnemonic = mnemonicInput.last {
            mnemonicSuggestions = HDWallet.getSuggestions(forWord: String(lastMnemonic))
        } else {
            mnemonicSuggestions = .init()
        }

        mnemonicTextView.errorState = .none
    }
}

extension ImportWalletViewController: AddressTextFieldDelegate {
    func doneButtonTapped(for textField: AddressTextField) {
        view.endEditing(true)
    }

    func displayError(error: Error, for textField: AddressTextField) {
        textField.errorState = .error(error.localizedDescription)
    }

    func openQRCodeReader(for textField: AddressTextField) {
        openReader()
    }

    func didPaste(in textField: AddressTextField) {
        view.endEditing(true)
        showCorrectTab()
    }

    func shouldReturn(in textField: AddressTextField) -> Bool {
        moveFocusToTextEntryField(after: textField)
        return false
    }

    func didChange(to string: String, in textField: AddressTextField) {
        showCorrectTab()
    }
}

extension ImportWalletViewController: UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        mnemonicSuggestions.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: SeedPhraseSuggestionViewCell = collectionView.dequeueReusableCell(for: indexPath)
        cell.configure(word: mnemonicSuggestions[indexPath.row])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let words = replacingLastWord(of: mnemonicInput, with: "\(mnemonicSuggestions[indexPath.row]) ")
        mnemonicTextView.value = words.joined(separator: " ")
    }

    private func replacingLastWord(of words: [String], with replacement: String) -> [String] {
        var words = words
        words.removeLast()
        words.append(replacement)
        return words
    }
}
