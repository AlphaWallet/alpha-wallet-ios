// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import TrustWalletCore

protocol ImportWalletViewControllerDelegate: class {
    func didImportAccount(account: Wallet, in viewController: ImportWalletViewController)
    func openQRCode(in controller: ImportWalletViewController)
}

// swiftlint:disable type_body_length
class ImportWalletViewController: UIViewController, CanScanQRCode {
    struct ValidationError: LocalizedError {
        var msg: String
        var errorDescription: String? {
            return msg
        }
    }

    private static let menmonicSuggestionsBarHeight: CGFloat = 60

    private let keystore: Keystore
    private let viewModel = ImportWalletViewModel()
    //We don't actually use the rounded corner here, but it's a useful "content" view here
    private let roundedBackground = RoundedBackground()
    private let scrollView = UIScrollView()
    private let tabBar = SegmentedControl(titles: ImportWalletViewModel.segmentedControlTitles)
    private let mnemonicCountLabel = UILabel()
    private let mnemonicTextView = TextView()
    private let keystoreJSONTextView = TextView()
    private let passwordTextField = TextField()
    private let privateKeyTextView = TextView()
    private let watchAddressTextField = AddressTextField()
    private var mnemonicControlsStackView: UIStackView!
    private var keystoreJSONControlsStackView: UIStackView!
    private var privateKeyControlsStackView: UIStackView!
    private var watchControlsStackView: UIStackView!
    private let importKeystoreJsonFromCloudButton = UIButton(type: .system)
    private let importSeedDescriptionLabel = UILabel()
    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))
    private var mnemonicSuggestions: [String] = .init() {
        didSet {
            mnemonicSuggestionsCollectionView.reloadData()
        }
    }

    private let mnemonicSuggestionsCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.estimatedItemSize = CGSize(width: 140, height: 40)
        layout.scrollDirection = .horizontal

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.contentInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        cv.register(SeedPhraseSuggestionViewCell.self, forCellWithReuseIdentifier: SeedPhraseSuggestionViewCell.identifier)

        return cv
    }()

    private var mnemonicInput: [String] {
        mnemonicInputString.split(separator: " ").map { String($0) }
    }

    private var mnemonicInputString: String {
        mnemonicTextView.value.lowercased()
    }

    weak var delegate: ImportWalletViewControllerDelegate?

// swiftlint:disable function_body_length
    init(keystore: Keystore) {
        self.keystore = keystore
        super.init(nibName: nil, bundle: nil)

        title = viewModel.title
        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(scrollView)

        tabBar.delegate = self
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabBar)

        mnemonicTextView.label.translatesAutoresizingMaskIntoConstraints = false
        mnemonicTextView.delegate = self
        mnemonicTextView.translatesAutoresizingMaskIntoConstraints = false
        mnemonicTextView.returnKeyType = .done
        mnemonicTextView.textView.autocorrectionType = .no
        mnemonicTextView.textView.autocapitalizationType = .none

        mnemonicCountLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mnemonicCountLabel)

        keystoreJSONTextView.label.translatesAutoresizingMaskIntoConstraints = false
        keystoreJSONTextView.delegate = self
        keystoreJSONTextView.translatesAutoresizingMaskIntoConstraints = false
        keystoreJSONTextView.returnKeyType = .next
        keystoreJSONTextView.textView.autocorrectionType = .no
        keystoreJSONTextView.textView.autocapitalizationType = .none

        passwordTextField.label.translatesAutoresizingMaskIntoConstraints = false
        passwordTextField.delegate = self
        passwordTextField.translatesAutoresizingMaskIntoConstraints = false
        passwordTextField.textField.autocorrectionType = .no
        passwordTextField.textField.autocapitalizationType = .none
        passwordTextField.returnKeyType = .done
        passwordTextField.isSecureTextEntry = false
        passwordTextField.textField.clearButtonMode = .whileEditing
        passwordTextField.textField.rightView = {
            let button = UIButton(type: .system)
            button.frame = .init(x: 0, y: 0, width: 30, height: 30)
            button.setImage(R.image.togglePassword(), for: .normal)
            button.tintColor = .init(red: 111, green: 111, blue: 111)
            button.addTarget(self, action: #selector(self.toggleMaskPassword), for: .touchUpInside)
            return button
        }()
        passwordTextField.textField.rightViewMode = .unlessEditing

        privateKeyTextView.label.translatesAutoresizingMaskIntoConstraints = false
        privateKeyTextView.delegate = self
        privateKeyTextView.translatesAutoresizingMaskIntoConstraints = false
        privateKeyTextView.returnKeyType = .done
        privateKeyTextView.textView.autocorrectionType = .no
        privateKeyTextView.textView.autocapitalizationType = .none

        watchAddressTextField.translatesAutoresizingMaskIntoConstraints = false
        watchAddressTextField.delegate = self
        watchAddressTextField.returnKeyType = .done

        mnemonicControlsStackView = [
            mnemonicTextView.label,
            .spacer(height: 4),
            mnemonicTextView,
            .spacer(height: 4),
            mnemonicTextView.statusLabel
        ].asStackView(axis: .vertical)
        mnemonicControlsStackView.translatesAutoresizingMaskIntoConstraints = false

        keystoreJSONControlsStackView = [
            keystoreJSONTextView.label,
            .spacer(height: 4),
            keystoreJSONTextView,
            .spacer(height: 4),
            keystoreJSONTextView.statusLabel,
            .spacer(height: 10),
            passwordTextField.label,
            .spacer(height: 4),
            passwordTextField,
            .spacer(height: 4),
            passwordTextField.statusLabel
        ].asStackView(axis: .vertical)
        keystoreJSONControlsStackView.translatesAutoresizingMaskIntoConstraints = false

        privateKeyControlsStackView = [
            privateKeyTextView.label,
            .spacer(height: 4),
            privateKeyTextView,
            .spacer(height: 4),
            privateKeyTextView.statusLabel
        ].asStackView(axis: .vertical)
        privateKeyControlsStackView.translatesAutoresizingMaskIntoConstraints = false

        let addressControlsContainer = UIView()
        addressControlsContainer.translatesAutoresizingMaskIntoConstraints = false
        addressControlsContainer.backgroundColor = .clear

        let addressControlsStackView = [
            watchAddressTextField.pasteButton,
            watchAddressTextField.clearButton
        ].asStackView(axis: .horizontal)
        addressControlsStackView.translatesAutoresizingMaskIntoConstraints = false

        addressControlsContainer.addSubview(addressControlsStackView)

        watchControlsStackView = [
            watchAddressTextField.label,
            .spacer(height: 4),
            watchAddressTextField,
            .spacer(height: 4), [
                watchAddressTextField.ensAddressView,
                addressControlsContainer
            ].asStackView(axis: .horizontal),
            .spacer(height: 4),

        ].asStackView(axis: .vertical)
        watchControlsStackView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = [
            tabBar,
            .spacer(height: 10),
            mnemonicControlsStackView,
            keystoreJSONControlsStackView,
            privateKeyControlsStackView,
            watchControlsStackView,
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        importKeystoreJsonFromCloudButton.isHidden = true
        importKeystoreJsonFromCloudButton.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(importKeystoreJsonFromCloudButton)

        importSeedDescriptionLabel.isHidden = false
        importSeedDescriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        importSeedDescriptionLabel.textAlignment = .center
        roundedBackground.addSubview(importSeedDescriptionLabel)

        mnemonicSuggestionsCollectionView.frame = .init(x: 0, y: 0, width: 0, height: ImportWalletViewController.menmonicSuggestionsBarHeight)

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = .clear
        roundedBackground.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)

        let xMargin  = CGFloat(7)
        let heightThatFitsPrivateKeyNicely = CGFloat(100)
        NSLayoutConstraint.activate([
            mnemonicTextView.heightAnchor.constraint(equalToConstant: heightThatFitsPrivateKeyNicely),
            keystoreJSONTextView.heightAnchor.constraint(equalToConstant: heightThatFitsPrivateKeyNicely),
            privateKeyTextView.heightAnchor.constraint(equalToConstant: heightThatFitsPrivateKeyNicely),

            tabBar.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 44),

            mnemonicControlsStackView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: xMargin),
            mnemonicControlsStackView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: -xMargin),

            mnemonicCountLabel.topAnchor.constraint(equalTo: mnemonicControlsStackView.bottomAnchor, constant: xMargin),
            mnemonicCountLabel.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: -xMargin),

            keystoreJSONControlsStackView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: xMargin),
            keystoreJSONControlsStackView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: -xMargin),
            privateKeyControlsStackView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: xMargin),
            privateKeyControlsStackView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: -xMargin),
            watchControlsStackView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: xMargin),
            watchControlsStackView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: -xMargin),

            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            importKeystoreJsonFromCloudButton.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor, constant: 10),
            importKeystoreJsonFromCloudButton.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor, constant: -10),
            importKeystoreJsonFromCloudButton.bottomAnchor.constraint(equalTo: footerBar.topAnchor, constant: -20),

            importSeedDescriptionLabel.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor, constant: 30),
            importSeedDescriptionLabel.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor, constant: -30),
            importSeedDescriptionLabel.bottomAnchor.constraint(equalTo: footerBar.topAnchor, constant: -20),

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

            addressControlsStackView.trailingAnchor.constraint(equalTo: addressControlsContainer.trailingAnchor),
            addressControlsStackView.topAnchor.constraint(equalTo: addressControlsContainer.topAnchor),
            addressControlsStackView.bottomAnchor.constraint(equalTo: addressControlsContainer.bottomAnchor),
            addressControlsStackView.leadingAnchor.constraint(greaterThanOrEqualTo: addressControlsContainer.leadingAnchor),

        ] + roundedBackground.createConstraintsWithContainer(view: view))

        configure()
        showMnemonicControlsOnly()

        navigationItem.rightBarButtonItem = UIBarButtonItem(image: R.image.qr_code_icon(), style: .done, target: self, action: #selector(openReader))

        if UserDefaults.standard.bool(forKey: "FASTLANE_SNAPSHOT") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.demo()
            }
        }
    }
// swiftlint:enable function_body_length

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //Because we want the filter to look like it's a part of the navigation bar
        navigationController?.navigationBar.shadowImage = UIImage()
    }

    private func showCorrectTab() {
        guard let tab = viewModel.convertSegmentedControlSelectionToFilter(tabBar.selection) else { return }
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
        //TODO shouldn't this be done in a view model?
        tabBar.selection = .selected(ImportWalletTab.watch.selectionIndex)
        showCorrectTab()
    }

    func configure() {
        view.backgroundColor = viewModel.backgroundColor

        mnemonicTextView.configureOnce()
        mnemonicTextView.label.text = viewModel.mnemonicLabel

        mnemonicCountLabel.font = DataEntry.Font.label
        mnemonicCountLabel.textColor = DataEntry.Color.label

        mnemonicSuggestionsCollectionView.backgroundColor = .white
        mnemonicSuggestionsCollectionView.backgroundColor = R.color.mike()
        mnemonicSuggestionsCollectionView.showsHorizontalScrollIndicator = false
        mnemonicSuggestionsCollectionView.delegate = self
        mnemonicSuggestionsCollectionView.dataSource = self

        keystoreJSONTextView.configureOnce()
        keystoreJSONTextView.label.text = viewModel.keystoreJSONLabel

        passwordTextField.configureOnce()
        passwordTextField.label.text = viewModel.passwordLabel

        privateKeyTextView.configureOnce()
        privateKeyTextView.label.text = viewModel.privateKeyLabel

        watchAddressTextField.label.text = viewModel.watchAddressLabel
        watchAddressTextField.configureOnce()

        importKeystoreJsonFromCloudButton.addTarget(self, action: #selector(importOptions), for: .touchUpInside)
        importKeystoreJsonFromCloudButton.setTitle(R.string.localizable.importWalletImportFromCloudTitle(), for: .normal)
        importKeystoreJsonFromCloudButton.titleLabel?.font = viewModel.importKeystoreJsonButtonFont
        importKeystoreJsonFromCloudButton.titleLabel?.adjustsFontSizeToFitWidth = true

        importSeedDescriptionLabel.font = viewModel.importSeedDescriptionFont
        importSeedDescriptionLabel.textColor = viewModel.importSeedDescriptionColor
        importSeedDescriptionLabel.text = R.string.localizable.importWalletImportSeedPhraseDescription()
        importSeedDescriptionLabel.numberOfLines = 0

        buttonsBar.configure()
        let importButton = buttonsBar.buttons[0]
        importButton.addTarget(self, action: #selector(importWallet), for: .touchUpInside)
        configureImportButtonTitle(R.string.localizable.importWalletImportButtonTitle())
    }

    private func configureImportButtonTitle(_ title: String) {
        let importButton = buttonsBar.buttons[0]
        importButton.setTitle(title, for: .normal)
    }

    func didImport(account: Wallet) {
        delegate?.didImportAccount(account: account, in: self)
    }

    ///Returns true only if valid
    private func validate() -> Bool {
        guard let tab = viewModel.convertSegmentedControlSelectionToFilter(tabBar.selection) else { return false }
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

        if let validationError = MnemonicLengthRule().isValid(value: mnemonicInputString) {
            mnemonicTextView.errorState = .error(validationError.msg)

            return false
        }
        if let validationError = MnemonicInWordListRule().isValid(value: mnemonicInputString) {
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
        if let validationError = PrivateKeyRule().isValid(value: privateKeyTextView.value.trimmed) {
            privateKeyTextView.errorState = .error(validationError.msg)
            return false
        }
        return true
    }

    ///Returns true only if valid
    private func validateWatch() -> Bool {
        watchAddressTextField.errorState = .none
        if let validationError = EthereumAddressRule().isValid(value: watchAddressTextField.value) {
            watchAddressTextField.errorState = .error(validationError.msg)
            return false
        }
        return true
    }

    @objc func importWallet() {
        guard validate() else { return }

        let keystoreInput = keystoreJSONTextView.value.trimmed
        let privateKeyInput = privateKeyTextView.value.trimmed.drop0x
        let password = passwordTextField.value.trimmed
        let watchInput = watchAddressTextField.value.trimmed

        displayLoading(text: R.string.localizable.importWalletImportingIndicatorLabelTitle(), animated: false)

        let importTypeOptional: ImportType? = {
            guard let tab = viewModel.convertSegmentedControlSelectionToFilter(tabBar.selection) else { return nil }
            switch tab {
            case .mnemonic:
                return .mnemonic(words: mnemonicInput, password: "")
            case .keystore:
                return .keystore(string: keystoreInput, password: password)
            case .privateKey:
                guard let data = Data(hexString: privateKeyInput) else {
                    hideLoading(animated: false)
                    privateKeyTextView.errorState = .error(R.string.localizable.importWalletImportInvalidPrivateKey())
                    return nil
                }
                privateKeyTextView.errorState = .none
                return .privateKey(privateKey: data)
            case .watch:
                let address = AlphaWallet.Address(string: watchInput)! // Address validated by form view.
                return .watch(address: address)
            }
        }()
        guard let importType = importTypeOptional else { return }

        keystore.importWallet(type: importType) { [weak self] result in
            guard let strongSelf = self else { return }
            strongSelf.hideLoading(animated: false)
            switch result {
            case .success(let account):
                strongSelf.didImport(account: account)
            case .failure(let error):
                strongSelf.displayError(error: error)
            }
        }
    }

    @objc func demo() {
        //Used for taking screenshots to the App Store by snapshot
        let demoWallet = Wallet(type: .watch(AlphaWallet.Address(string: "0xD663bE6b87A992C5245F054D32C7f5e99f5aCc47")!))
        delegate?.didImportAccount(account: demoWallet, in: self)
    }

    @objc func importOptions(sender: UIButton) {
        let alertController = UIAlertController(
            title: R.string.localizable.importWalletImportAlertSheetTitle(),
            message: .none,
            preferredStyle: .actionSheet
        )
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
        case .unspecified, .tv, .carPlay, .phone:
            controller.makePresentationFullScreenForiOS13Migration()
        }
        present(controller, animated: true, completion: nil)
    }

    @objc func openReader() {
        delegate?.openQRCode(in: self)
    }

    func setValueForCurrentField(string: String) {
        guard let tab = viewModel.convertSegmentedControlSelectionToFilter(tabBar.selection) else { return }
        switch tab {
        case .mnemonic:
            mnemonicTextView.value = string
        case .keystore:
            keystoreJSONTextView.value = string
        case .privateKey:
            privateKeyTextView.value = string
        case .watch:
            watchAddressTextField.value = string
        }
        showCorrectTab()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func showMnemonicControlsOnly() {
        mnemonicControlsStackView.isHidden = false
        keystoreJSONControlsStackView.isHidden = true
        privateKeyControlsStackView.isHidden = true
        watchControlsStackView.isHidden = true
        configureImportButtonTitle(R.string.localizable.importWalletImportButtonTitle())
        importKeystoreJsonFromCloudButton.isHidden = true
        importSeedDescriptionLabel.isHidden = false
        let importButton = buttonsBar.buttons[0]
        importButton.isEnabled = !mnemonicTextView.value.isEmpty
        mnemonicTextView.textView.inputAccessoryView = mnemonicSuggestionsCollectionView
        mnemonicTextView.textView.reloadInputViews()
    }

    private func showKeystoreControlsOnly() {
        mnemonicControlsStackView.isHidden = true
        keystoreJSONControlsStackView.isHidden = false
        privateKeyControlsStackView.isHidden = true
        watchControlsStackView.isHidden = true
        configureImportButtonTitle(R.string.localizable.importWalletImportButtonTitle())
        importKeystoreJsonFromCloudButton.isHidden = false
        importSeedDescriptionLabel.isHidden = true
        let importButton = buttonsBar.buttons[0]
        importButton.isEnabled = !keystoreJSONTextView.value.isEmpty && !passwordTextField.value.isEmpty
        mnemonicTextView.textView.inputAccessoryView = nil
        mnemonicTextView.textView.reloadInputViews()
    }

    private func showPrivateKeyControlsOnly() {
        mnemonicControlsStackView.isHidden = true
        keystoreJSONControlsStackView.isHidden = true
        privateKeyControlsStackView.isHidden = false
        watchControlsStackView.isHidden = true
        configureImportButtonTitle(R.string.localizable.importWalletImportButtonTitle())
        importKeystoreJsonFromCloudButton.isHidden = true
        importSeedDescriptionLabel.isHidden = true
        let importButton = buttonsBar.buttons[0]
        importButton.isEnabled = !privateKeyTextView.value.isEmpty
        mnemonicTextView.textView.inputAccessoryView = nil
        mnemonicTextView.textView.reloadInputViews()
    }

    private func showWatchControlsOnly() {
        mnemonicControlsStackView.isHidden = true
        keystoreJSONControlsStackView.isHidden = true
        privateKeyControlsStackView.isHidden = true
        watchControlsStackView.isHidden = false
        configureImportButtonTitle(R.string.localizable.walletWatchButtonTitle())
        importKeystoreJsonFromCloudButton.isHidden = true
        importSeedDescriptionLabel.isHidden = true
        let importButton = buttonsBar.buttons[0]
        importButton.isEnabled = !watchAddressTextField.value.isEmpty
        mnemonicTextView.textView.inputAccessoryView = nil
        mnemonicTextView.textView.reloadInputViews()
    }

    private func moveFocusToTextEntryField(after textInput: UIView) {
        switch textInput {
        case mnemonicTextView:
            view.endEditing(true)
        case keystoreJSONTextView:
            _ = passwordTextField.becomeFirstResponder()
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

    @objc private func toggleMaskPassword() {
        passwordTextField.isSecureTextEntry = !passwordTextField.isSecureTextEntry
        guard let button = passwordTextField.textField.rightView as? UIButton else { return }
        if passwordTextField.isSecureTextEntry {
            button.tintColor = Colors.appTint
        } else {
            button.tintColor = .init(red: 111, green: 111, blue: 111)
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
    }
}

extension ImportWalletViewController: AddressTextFieldDelegate {
    func displayError(error: Error, for textField: AddressTextField) {
        textField.errorState = .error(error.prettyError)
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

extension ImportWalletViewController: SegmentedControlDelegate {
    func didTapSegment(atSelection selection: SegmentedControl.Selection, inSegmentedControl segmentedControl: SegmentedControl) {
        tabBar.selection = selection
        showCorrectTab()
    }
}

extension ImportWalletViewController: UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        mnemonicSuggestions.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SeedPhraseSuggestionViewCell.identifier, for: indexPath) as? SeedPhraseSuggestionViewCell else { return SeedPhraseSuggestionViewCell() }
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
