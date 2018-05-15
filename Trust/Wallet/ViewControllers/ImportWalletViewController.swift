// Copyright SIX DAY LLC. All rights reserved.
import UIKit
import BonMot
import TrustKeystore
import QRCodeReaderViewController

protocol ImportWalletViewControllerDelegate: class {
    func didImportAccount(account: Wallet, in viewController: ImportWalletViewController)
}

class ImportWalletViewController: UIViewController {
    struct ValidationError: LocalizedError {
        var msg: String
        var errorDescription: String? {
            return msg
        }
    }

    let keystore: Keystore
    private let viewModel = ImportWalletViewModel()

    //We don't actually use the rounded corner here, but it's a useful "content" view here
    let roundedBackground = RoundedBackground()
    let scrollView = UIScrollView()
    let footerBar = UIView()
    let tabBar = ImportWalletTabBar()
    let keystoreJSONTextView = TextView()
    let passwordTextField = TextField()
    let privateKeyTextView = TextView()
    let watchAddressTextField = AddressTextField()

    var keystoreJSONControlsStackView: UIStackView!
    var privateKeyControlsStackView: UIStackView!
    var watchControlsStackView: UIStackView!

    let importButton = UIButton(type: .system)

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

        keystoreJSONTextView.label.translatesAutoresizingMaskIntoConstraints = false
        keystoreJSONTextView.delegate = self
        keystoreJSONTextView.translatesAutoresizingMaskIntoConstraints = false
        keystoreJSONTextView.textView.returnKeyType = .next

        passwordTextField.label.translatesAutoresizingMaskIntoConstraints = false
        passwordTextField.delegate = self
        passwordTextField.translatesAutoresizingMaskIntoConstraints = false
        passwordTextField.textField.returnKeyType = .done
        passwordTextField.textField.isSecureTextEntry = true

        privateKeyTextView.label.translatesAutoresizingMaskIntoConstraints = false
        privateKeyTextView.delegate = self
        privateKeyTextView.translatesAutoresizingMaskIntoConstraints = false
        privateKeyTextView.textView.returnKeyType = .done

        watchAddressTextField.translatesAutoresizingMaskIntoConstraints = false
        watchAddressTextField.delegate = self
        watchAddressTextField.textField.returnKeyType = .done

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
        ].asStackView(axis: .vertical)
        watchControlsStackView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = [
            tabBar,
            .spacer(height: 10),
            keystoreJSONControlsStackView,
            privateKeyControlsStackView,
            watchControlsStackView,
        ].asStackView(axis: .vertical, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        importButton.setTitle(R.string.localizable.importWalletImportButtonTitle(), for: .normal)
        importButton.addTarget(self, action: #selector(importWallet), for: .touchUpInside)

        let buttonsStackView = [importButton].asStackView(distribution: .fillEqually, contentHuggingPriority: .required)
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false

        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = Colors.appHighlightGreen
        roundedBackground.addSubview(footerBar)

        let buttonsHeight = CGFloat(60)
        footerBar.addSubview(buttonsStackView)

        let xMargin  = CGFloat(7)
        let heightThatFitsPrivateKeyNicely = CGFloat(100)
        NSLayoutConstraint.activate([
            keystoreJSONTextView.heightAnchor.constraint(equalToConstant: heightThatFitsPrivateKeyNicely),
            privateKeyTextView.heightAnchor.constraint(equalToConstant: heightThatFitsPrivateKeyNicely),

            tabBar.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),

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

        configure()
        showKeystoreControlsOnly()

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: R.image.import_options(), style: .done, target: self, action: #selector(importOptions)),
            UIBarButtonItem(image: R.image.qr_code_icon(), style: .done, target: self, action: #selector(openReader)),
        ]

        if UserDefaults.standard.bool(forKey: "FASTLANE_SNAPSHOT") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.demo()
            }
        }
    }

    func configure() {
        view.backgroundColor = viewModel.backgroundColor

        keystoreJSONTextView.configureOnce()
        keystoreJSONTextView.label.textAlignment = .center
        keystoreJSONTextView.label.text = viewModel.keystoreJSONLabel

        passwordTextField.configureOnce()
        passwordTextField.label.textAlignment = .center
        passwordTextField.label.text = viewModel.passwordLabel

        privateKeyTextView.configureOnce()
        privateKeyTextView.label.textAlignment = .center
        privateKeyTextView.label.text = viewModel.privateKeyLabel

        watchAddressTextField.configureOnce()
        watchAddressTextField.label.textAlignment = .center
        watchAddressTextField.label.text = viewModel.watchAddressLabel

        importButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
        importButton.backgroundColor = viewModel.buttonBackgroundColor
        importButton.titleLabel?.font = viewModel.buttonFont
    }

    func didImport(account: Wallet) {
        delegate?.didImportAccount(account: account, in: self)
    }

    ///Returns true only if valid
    private func validate() -> Bool {
        switch tabBar.tab {
        case .keystore:
            return validateKeystore()
        case .privateKey:
            return validatePrivateKey()
        case .watch:
            return validateWatch()
        default:
            return true
        }
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
        if let validationError = PrivateKeyRule().isValid(value: privateKeyTextView.value) {
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

        let keystoreInput = keystoreJSONTextView.value.trimmed
        let privateKeyInput = privateKeyTextView.value.trimmed
        let password = passwordTextField.value.trimmed
        let watchInput = watchAddressTextField.value.trimmed

        displayLoading(text: R.string.localizable.importWalletImportingIndicatorLabelTitle(), animated: false)

        let importType: ImportType = {
            switch tabBar.tab {
            case .keystore:
                return .keystore(string: keystoreInput, password: password)
            case .privateKey:
                return .privateKey(privateKey: privateKeyInput)
            case .watch:
                let address = Address(string: watchInput)! // Address validated by form view.
                return .watch(address: address)
            }
        }()

        keystore.importWallet(type: importType) { result in
            self.hideLoading(animated: false)
            switch result {
            case .success(let account):
                self.didImport(account: account)
            case .failure(let error):
                self.displayError(error: error)
            }
        }
    }

    @objc func demo() {
        //Used for taking screenshots to the App Store by snapshot
        let demoWallet = Wallet(type: .watch(Address(string: "0xD663bE6b87A992C5245F054D32C7f5e99f5aCc47")!))
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
        ) { _ in
            self.showDocumentPicker()
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
        let controller = QRCodeReaderViewController()
        controller.delegate = self
        present(controller, animated: true, completion: nil)
    }

    func setValueForCurrentField(string: String) {
        switch tabBar.tab {
        case .keystore:
            keystoreJSONTextView.value = string
        case .privateKey:
            privateKeyTextView.value = string
        case .watch:
            watchAddressTextField.value = string
        default:
            return
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func showKeystoreControlsOnly() {
        keystoreJSONControlsStackView.isHidden = false
        privateKeyControlsStackView.isHidden = true
        watchControlsStackView.isHidden = true
    }
    private func showPrivateKeyControlsOnly() {
        keystoreJSONControlsStackView.isHidden = true
        privateKeyControlsStackView.isHidden = false
        watchControlsStackView.isHidden = true
    }
    private func showWatchControlsOnly() {
        keystoreJSONControlsStackView.isHidden = true
        privateKeyControlsStackView.isHidden = true
        watchControlsStackView.isHidden = false
    }

    private func moveFocusToTextEntryField(after textInput: UIView) {
        switch textInput {
        case keystoreJSONTextView.textView:
            passwordTextField.textField.becomeFirstResponder()
        case passwordTextField.textField:
            view.endEditing(true)
        case privateKeyTextView.textView:
            view.endEditing(true)
        case watchAddressTextField.textField:
            view.endEditing(true)
        default:
            break
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
        moveFocusToTextEntryField(after: textField.textField)
        return false
    }

    func doneButtonTapped(for textField: TextField) {
        view.endEditing(true)
    }

    func nextButtonTapped(for textField: TextField) {
        moveFocusToTextEntryField(after: textField.textField)
    }
}

extension ImportWalletViewController: TextViewDelegate {
    func shouldReturn(in textView: TextView) -> Bool {
        moveFocusToTextEntryField(after: textView.textView)
        return false
    }

    func doneButtonTapped(for textView: TextView) {
        view.endEditing(true)
    }

    func nextButtonTapped(for textView: TextView) {
        moveFocusToTextEntryField(after: textView.textView)
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
    }

    func shouldReturn(in textField: AddressTextField) -> Bool {
        moveFocusToTextEntryField(after: textField.textField)
        return false
    }

    func shouldChange(in range: NSRange, to string: String, in textField: AddressTextField) -> Bool {
        return true
    }
}

extension ImportWalletViewController: ImportWalletTabBarDelegate {
    func didPressImportWalletTab(tab: ImportWalletTab, in tabBar: ImportWalletTabBar) {
        switch tab {
        case .keystore:
            showKeystoreControlsOnly()
        case .privateKey:
            showPrivateKeyControlsOnly()
        case .watch:
            showWatchControlsOnly()
        default:
            break
        }
    }
}
