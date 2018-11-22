// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol AddressTextFieldDelegate: class {
    func displayError(error: Error, for textField: AddressTextField)
    func openQRCodeReader(for textField: AddressTextField)
    func didPaste(in textField: AddressTextField)
    func shouldReturn(in textField: AddressTextField) -> Bool
    func didChange(to string: String, in textField: AddressTextField)
}

class AddressTextField: UIControl {
    private static let MINIMUM_ENS_NAME_LENGTH = 6 //We assume .co is possible in the future, so: a.b.co
    private static let DELAY_AFTER_STOP_TYPING_TO_START_RESOLVING_ENS_NAME = TimeInterval(0.5)
    private var isConfigured = false
    private let textField = UITextField()
    private var toStartResolvingEnsNameTimer: Timer?
    let label = UILabel()
    let ensAddressLabel = UILabel()

    var value: String {
        get {
            if let ensResolvedAddress = ensAddressLabel.text, !ensResolvedAddress.isEmpty {
                return ensResolvedAddress
            } else {
                return textField.text ?? ""
            }
        }
        set {
            //Client code sometimes sets back the address. We only set (and thus clear the ENS name) if it doesn't match the resolved address
            guard ensAddressLabel.text != newValue else { return }
            textField.text = newValue
            clearAddressFromResolvingEnsName()
        }
    }

    var returnKeyType: UIReturnKeyType {
        get {
            return textField.returnKeyType
        }
        set {
            textField.returnKeyType = newValue
        }
    }

    weak var delegate: AddressTextFieldDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)

        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.delegate = self
        textField.leftViewMode = .always
        textField.rightViewMode = .always
        addSubview(textField)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textColor = Colors.appGrayLabelColor
        label.font = Fonts.regular(size: 10)!
        label.textAlignment = .center

        ensAddressLabel.translatesAutoresizingMaskIntoConstraints = false
        ensAddressLabel.numberOfLines = 0
        ensAddressLabel.textColor = Colors.appGrayLabelColor
        ensAddressLabel.font = Fonts.regular(size: 10)!
        ensAddressLabel.textAlignment = .center

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor),
            textField.topAnchor.constraint(equalTo: topAnchor),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: ScreenChecker().isNarrowScreen() ? 30 : 50),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
        return textField.becomeFirstResponder()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        roundCornersBasedOnHeight()
    }

    private func roundCornersBasedOnHeight() {
        textField.layer.cornerRadius = textField.frame.size.height / 2
    }

    func configureOnce() {
        guard !isConfigured else { return }
        isConfigured = true

        label.font = Fonts.regular(size: 10)!
        label.textColor = Colors.appGrayLabelColor

        ensAddressLabel.font = Fonts.regular(size: 10)!
        ensAddressLabel.textColor = Colors.appGrayLabelColor

        textField.leftView = .spacerWidth(22)
        textField.rightView = makeTargetAddressRightView()
        textField.textColor = Colors.appText
        textField.font = ScreenChecker().isNarrowScreen() ? Fonts.light(size: 11)! : Fonts.light(size: 15)!
        textField.layer.borderColor = Colors.appBackground.cgColor
        textField.layer.borderWidth = 1
        textField.placeholder = R.string.localizable.addressEnsLabelMessage()
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
    }

    private func makeTargetAddressRightView() -> UIView {
        let pasteButton = Button(size: .normal, style: .borderless)
        pasteButton.translatesAutoresizingMaskIntoConstraints = false
        pasteButton.setTitle(R.string.localizable.sendPasteButtonTitle(), for: .normal)
        pasteButton.titleLabel?.font = Fonts.regular(size: 14)!
        pasteButton.setTitleColor(Colors.appGrayLabelColor, for: .normal)
        pasteButton.addTarget(self, action: #selector(pasteAction), for: .touchUpInside)

        let scanQRCodeButton = Button(size: .normal, style: .borderless)
        scanQRCodeButton.translatesAutoresizingMaskIntoConstraints = false
        scanQRCodeButton.setImage(R.image.qr_code_icon(), for: .normal)
        scanQRCodeButton.setTitleColor(Colors.appGrayLabelColor, for: .normal)
        scanQRCodeButton.addTarget(self, action: #selector(openReader), for: .touchUpInside)

        let targetAddressRightView = [pasteButton, scanQRCodeButton].asStackView(distribution: .equalSpacing)
        targetAddressRightView.translatesAutoresizingMaskIntoConstraints = false

        return targetAddressRightView
    }

    @objc func pasteAction() {
        guard let value = UIPasteboard.general.string?.trimmed else {
            delegate?.displayError(error: SendInputErrors.emptyClipBoard, for: self)
            return
        }
        if CryptoAddressValidator.isValidAddress(value) {
            self.value = value
            delegate?.didPaste(in: self)
            return
        } else if !value.contains(".") {
            delegate?.displayError(error: Errors.invalidAddress, for: self)
            return
        } else {
            textField.text = value
            GetENSOwnerCoordinator(config: Config()).getENSOwner(for: value) { result in
                if let address = result.value {
                    guard CryptoAddressValidator.isValidAddress(address.address) else {
                        self.delegate?.displayError(error: Errors.invalidAddress, for: self)
                        return
                    }
                    self.ensAddressLabel.text = address.address
                    self.delegate?.didPaste(in: self)
                } else {
                    self.delegate?.displayError(error: result.error?.error ?? Errors.invalidAddress, for: self)
                }
            }
        }
    }

    @objc func openReader() {
        delegate?.openQRCodeReader(for: self)
    }

    private func setToStartResolvingEnsNameTimer() {
        toStartResolvingEnsNameTimer?.invalidate()
        //TODO should only resolve one at a time
        toStartResolvingEnsNameTimer = Timer.scheduledTimer(withTimeInterval: AddressTextField.DELAY_AFTER_STOP_TYPING_TO_START_RESOLVING_ENS_NAME, repeats: false) { _ in
            if let value = self.textField.text?.trimmed {
                //TODO extract duplicate calls to GetENSOwnerCoordinator in this class
                GetENSOwnerCoordinator(config: Config()).getENSOwner(for: value) { result in
                    if let address = result.value {
                        guard CryptoAddressValidator.isValidAddress(address.address) else {
                            //TODO good to show an error message in the UI/label that it is not a valid ENS name
                            return
                        }
                        self.ensAddressLabel.text = address.address
                    }
                }
            }
        }
    }

    private func clearAddressFromResolvingEnsName() {
        ensAddressLabel.text = nil
    }

    private func isPossible(ensName: String?) -> Bool {
        if let ensName = ensName, ensName.count >= AddressTextField.MINIMUM_ENS_NAME_LENGTH && ensName.contains(".") {
            return true
        } else {
            return false
        }
    }
}

extension AddressTextField: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let delegate = delegate else { return true }
        return delegate.shouldReturn(in: self)
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        clearAddressFromResolvingEnsName()
        guard delegate != nil else { return true }
        let newValue = (self.textField.text as NSString?)?.replacingCharacters(in: range, with: string)
        if let newValue = newValue, CryptoAddressValidator.isValidAddress(newValue) {
        } else {
            if isPossible(ensName: newValue) {
                setToStartResolvingEnsNameTimer()
            }
        }
        informDelegateDidChange(to: newValue ?? "")
        return true
    }

    private func informDelegateDidChange(to string: String) {
        //DispatchQueue because the textfield hasn't been updated yet
        DispatchQueue.global().async { [weak self] in
            DispatchQueue.main.sync { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.didChange(to: string, in: strongSelf)
            }
        }
    }
}
