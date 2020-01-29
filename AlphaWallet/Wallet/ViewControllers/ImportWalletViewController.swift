// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import QRCodeReaderViewController
import TrustWalletCore

protocol ImportWalletViewControllerDelegate: class {
    func didImportAccount(account: Wallet, in viewController: ImportWalletViewController)
}

class ImportWalletViewController: UIViewController, CanScanQRCode {
    struct ValidationError: LocalizedError {
        var msg: String
        var errorDescription: String? {
            return msg
        }
    }

    private let keystore: Keystore
    private let viewModel = ImportWalletViewModel()
    //We don't actually use the rounded corner here, but it's a useful "content" view here
    private let roundedBackground = RoundedBackground()
    private let scrollView = UIScrollView()
    private let tabBar = SegmentedControl(titles: ImportWalletViewModel.segmentedControlTitles)
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
    private let buttonsBar = ButtonsBar(numberOfButtons: 1)

    weak var delegate: ImportWalletViewControllerDelegate?

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
        ].asStackView(axis: .vertical)
        mnemonicControlsStackView.translatesAutoresizingMaskIntoConstraints = false

        keystoreJSONControlsStackView = [
            keystoreJSONTextView.label,
            .spacer(height: 4),
            keystoreJSONTextView,
            .spacer(height: 10),
            passwordTextField.label,
            .spacer(height: 4),
            passwordTextField,
        ].asStackView(axis: .vertical)
        keystoreJSONControlsStackView.translatesAutoresizingMaskIntoConstraints = false

        privateKeyControlsStackView = [
            privateKeyTextView.label,
            .spacer(height: 4),
            privateKeyTextView,
        ].asStackView(axis: .vertical)
        privateKeyControlsStackView.translatesAutoresizingMaskIntoConstraints = false

        watchControlsStackView = [
            watchAddressTextField.label,
            .spacer(height: 4),
            watchAddressTextField,
            watchAddressTextField.ensAddressLabel,
        ].asStackView(axis: .vertical)
        watchControlsStackView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = [
            tabBar,
            .spacer(height: 10),
            mnemonicControlsStackView,
            keystoreJSONControlsStackView,
            privateKeyControlsStackView,
            watchControlsStackView,
        ].asStackView(axis: .vertical, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        importKeystoreJsonFromCloudButton.isHidden = true
        importKeystoreJsonFromCloudButton.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(importKeystoreJsonFromCloudButton)

        importSeedDescriptionLabel.isHidden = false
        importSeedDescriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        importSeedDescriptionLabel.textAlignment = .center
        roundedBackground.addSubview(importSeedDescriptionLabel)

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
        mnemonicTextView.label.textAlignment = .center
        mnemonicTextView.label.text = viewModel.mnemonicLabel

        keystoreJSONTextView.configureOnce()
        keystoreJSONTextView.label.textAlignment = .center
        keystoreJSONTextView.label.text = viewModel.keystoreJSONLabel

        passwordTextField.configureOnce()
        passwordTextField.label.textAlignment = .center
        passwordTextField.label.text = viewModel.passwordLabel

        privateKeyTextView.configureOnce()
        privateKeyTextView.label.textAlignment = .center
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
        if let validationError = MnemonicLengthRule().isValid(value: mnemonicTextView.value) {
            displayError(error: ValidationError(msg: validationError.msg))
            return false
        }
        if let validationError = MnemonicInWordListRule().isValid(value: mnemonicTextView.value) {
            displayError(error: ValidationError(msg: validationError.msg))
            return false
        }
        return true
    }

    ///Returns true only if valid
    private func validateKeystore() -> Bool {
        if keystoreJSONTextView.value.isEmpty {
            displayError(title: viewModel.keystoreJSONLabel, error: ValidationError(msg: R.string.localizable.warningFieldRequired()))
            return false
        }
        if passwordTextField.value.isEmpty {
            displayError(title: viewModel.passwordLabel, error: ValidationError(msg: R.string.localizable.warningFieldRequired()))
            return false
        }
        return true
    }

    ///Returns true only if valid
    private func validatePrivateKey() -> Bool {
        if let validationError = PrivateKeyRule().isValid(value: privateKeyTextView.value.trimmed) {
            displayError(error: ValidationError(msg: validationError.msg))
            return false
        }
        return true
    }

    ///Returns true only if valid
    private func validateWatch() -> Bool {
        if let validationError = EthereumAddressRule().isValid(value: watchAddressTextField.value) {
            displayError(error: ValidationError(msg: validationError.msg))
            return false
        }
        return true
    }

    @objc func importWallet() {
        guard validate() else { return }

        let mnemonicInput = mnemonicTextView.value.trimmed
        let keystoreInput = keystoreJSONTextView.value.trimmed
        let privateKeyInput = privateKeyTextView.value.trimmed.drop0x
        let password = passwordTextField.value.trimmed
        let watchInput = watchAddressTextField.value.trimmed

        displayLoading(text: R.string.localizable.importWalletImportingIndicatorLabelTitle(), animated: false)

        let importTypeOptional: ImportType? = {
            guard let tab = viewModel.convertSegmentedControlSelectionToFilter(tabBar.selection) else { return nil }
            switch tab {
            case .mnemonic:
                return .mnemonic(words: mnemonicInput.split(separator: " ").map { String($0) }, password: "")
            case .keystore:
                return .keystore(string: keystoreInput, password: password)
            case .privateKey:
                guard let data = Data(hexString: privateKeyInput) else {
                    hideLoading(animated: false)
                    displayError(error: ValidationError(msg: R.string.localizable.importWalletImportInvalidPrivateKey()))
                    return nil
                }
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

    @objc func importOptions(sender: UIBarButtonItem) {
        let alertController = UIAlertController(
            title: R.string.localizable.importWalletImportAlertSheetTitle(),
            message: .none,
            preferredStyle: .actionSheet
        )
        alertController.popoverPresentationController?.barButtonItem = sender
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
        controller.modalPresentationStyle = .formSheet
        present(controller, animated: true, completion: nil)
    }

    @objc func openReader() {
        guard AVCaptureDevice.authorizationStatus(for: .video) != .denied else {
            promptUserOpenSettingsToChangeCameraPermission()
            return
        }
        let controller = QRCodeReaderViewController(cancelButtonTitle: nil, chooseFromPhotoLibraryButtonTitle: R.string.localizable.photos())
        controller.delegate = self
        present(controller, animated: true, completion: nil)
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
            button.tintColor = Colors.navigationTitleColor
        } else {
            button.tintColor = .init(red: 111, green: 111, blue: 111)
        }
    }
}

extension ImportWalletViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        guard controller.documentPickerMode == UIDocumentPickerMode.import else { return }
        let text = try? String(contentsOfFile: url.path)
        if let text = text {
            keystoreJSONTextView.value = text
        }
    }
}

extension ImportWalletViewController: QRCodeReaderDelegate {
    func readerDidCancel(_ reader: QRCodeReaderViewController!) {
        reader.stopScanning()
        reader.dismiss(animated: true, completion: nil)
    }

    func reader(_ reader: QRCodeReaderViewController!, didScanResult result: String!) {
        reader.stopScanning()
        setValueForCurrentField(string: result)
        reader.dismiss(animated: true)
    }
}

extension ImportWalletViewController: TextFieldDelegate {
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
    }
}

extension ImportWalletViewController: AddressTextFieldDelegate {
    func displayError(error: Error, for textField: AddressTextField) {
        displayError(error: error)
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
