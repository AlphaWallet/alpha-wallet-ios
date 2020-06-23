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
    private var isConfigured = false
    private let textField = UITextField()
    //Always resolve on mainnet
    private let serverToResolveEns = RPCServer.main
    private var addressString: String? {
        switch addressOrEnsName {
        case .address(let value):
            return value.eip55String
        case .ensName, .none:
            return nil
        }
    }

    private var addressOrEnsName: AddressOrEnsName? {
        didSet {
            ensAddressLabel.text = addressOrEnsName?.stringValue
            ensAddressLabel.isHidden = ensAddressLabel.text == nil
        }
    }

    private var textFieldText: String {
        get {
            return textField.text ?? ""
        }
        set {
            textField.text = newValue

            let notification = Notification(name: UITextField.textDidChangeNotification, object: textField)
            NotificationCenter.default.post(notification)
        }
    }

    var pasteButton: Button = {
        let button = Button(size: .normal, style: .borderless)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(R.string.localizable.sendPasteButtonTitle(), for: .normal)
        button.titleLabel?.font = DataEntry.Font.accessory
        button.setTitleColor(DataEntry.Color.icon, for: .normal)
        button.setBackgroundColor(.clear, forState: .normal)
        button.contentHorizontalAlignment = .right

        return button
    }()

    var clearButton: Button = {
        let button = Button(size: .normal, style: .borderless)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Clear", for: .normal)
        button.titleLabel?.font = DataEntry.Font.accessory
        button.setTitleColor(DataEntry.Color.icon, for: .normal)
        button.setBackgroundColor(.clear, forState: .normal)
        button.contentHorizontalAlignment = .right

        return button
    }()

    let label = UILabel()
    let ensAddressLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        return label
    }()

    let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        return label
    }()


    var value: String {
        get {
            if let ensResolvedAddress = addressString, !ensResolvedAddress.isEmpty {
                return ensResolvedAddress
            } else {
                return textFieldText
            }
        }
        set {
            //Client code sometimes sets back the address. We only set (and thus clear the ENS name) if it doesn't match the resolved address
            guard addressOrEnsName?.stringValue != newValue else { return }
            textFieldText = newValue

            clearAddressFromResolvingEnsName()

            if CryptoAddressValidator.isValidAddress(newValue) {
                queueEnsResolution(ofValue: newValue)
            } else if newValue.isPossibleEnsName {
                queueAddressResolution(ofValue: newValue)
            }
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

    var errorState: TextField.TextFieldErrorState = .none {
        didSet {
            switch errorState {
            case .error(let error):
                statusLabel.textColor = DataEntry.Color.textFieldStatus
                statusLabel.text = error
                statusLabel.isHidden = error.isEmpty
                self.ensAddressLabel.isHidden = true
            case .none:
                statusLabel.text = nil
                statusLabel.isHidden = true
            }

            let borderColor = errorState.textFieldBorderColor(whileEditing: isFirstResponder)
            let shouldDropShadow = errorState.textFieldShowShadow(whileEditing: isFirstResponder)

            layer.borderColor = borderColor.cgColor

            dropShadow(color: shouldDropShadow ? borderColor : .clear, radius: DataEntry.Metric.shadowRadius)
        }
    }

    weak var delegate: AddressTextFieldDelegate?

    init() {
        super.init(frame: .zero)
        pasteButton.addTarget(self, action: #selector(pasteAction), for: .touchUpInside)
        clearButton.addTarget(self, action: #selector(clearAction), for: .touchUpInside)

        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.delegate = self
        textField.leftViewMode = .always
        textField.rightViewMode = .always
        addSubview(textField)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textColor = DataEntry.Color.label
        label.font = DataEntry.Font.label
        label.textAlignment = .center

        ensAddressLabel.translatesAutoresizingMaskIntoConstraints = false
        ensAddressLabel.numberOfLines = 0
        ensAddressLabel.textColor = DataEntry.Color.label
        ensAddressLabel.font = DataEntry.Font.label
        ensAddressLabel.textAlignment = .center
        updateClearAndPasteButtons(textFieldText)

        NSLayoutConstraint.activate([
            textField.anchorsConstraint(to: self),
            heightAnchor.constraint(equalToConstant: ScreenChecker().isNarrowScreen ? 30 : 50),
        ])

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(textDidChangeNotification(_:)),
                                               name: UITextField.textDidChangeNotification, object: nil)
    }

    @objc private func textDidChangeNotification(_ notification: Notification) {
        guard textField == notification.object as? UITextField, let text = textField.text else {
            return
        }

        updateClearAndPasteButtons(text)
    }

    private func updateClearAndPasteButtons(_ text: String) {
        clearButton.isHidden = text.isEmpty
        pasteButton.isHidden = !text.isEmpty
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
        return textField.becomeFirstResponder()
    }

    func configureOnce() {
        guard !isConfigured else { return }
        isConfigured = true

        cornerRadius = DataEntry.Metric.cornerRadius

        label.font = DataEntry.Font.textFieldTitle
        label.textColor = DataEntry.Color.label
        label.textAlignment = .left

        ensAddressLabel.font = DataEntry.Font.label
        ensAddressLabel.textColor = DataEntry.Color.ensText
        addressOrEnsName = nil
        textField.layer.cornerRadius = DataEntry.Metric.cornerRadius
        textField.leftView = .spacerWidth(16)
        textField.rightView = makeTargetAddressRightView()
        textField.textColor = DataEntry.Color.text
        textField.font = Fonts.regular(size: ScreenChecker().isNarrowScreen ? 10: 13)
        textField.layer.borderColor = DataEntry.Color.border.cgColor
        textField.layer.borderWidth = DataEntry.Metric.borderThickness
        textField.placeholder = R.string.localizable.addressEnsLabelMessage()
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no

        statusLabel.font = DataEntry.Font.textFieldStatus
        statusLabel.textColor = DataEntry.Color.textFieldStatus
        statusLabel.textAlignment = .left

        textField.textColor = DataEntry.Color.text
        textField.font = DataEntry.Font.textField

        layer.borderWidth = DataEntry.Metric.borderThickness
        backgroundColor = DataEntry.Color.textFieldBackground
        layer.borderColor = errorState.textFieldBorderColor(whileEditing: isFirstResponder).cgColor
        errorState = .none
    }

    private func makeTargetAddressRightView() -> UIView {
        let scanQRCodeButton = Button(size: .normal, style: .borderless)
        scanQRCodeButton.translatesAutoresizingMaskIntoConstraints = false
        scanQRCodeButton.setImage(R.image.qr_code_icon(), for: .normal)
        scanQRCodeButton.addTarget(self, action: #selector(openReader), for: .touchUpInside)
        scanQRCodeButton.setBackgroundColor(.clear, forState: .normal)

        let targetAddressRightView = [scanQRCodeButton].asStackView(distribution: .fill)
        //As of iOS 13, we need to constrain the width of `rightView`
        let rightViewFittingSize = targetAddressRightView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        NSLayoutConstraint.activate([
            targetAddressRightView.widthAnchor.constraint(equalToConstant: rightViewFittingSize.width),
        ])
        targetAddressRightView.translatesAutoresizingMaskIntoConstraints = false

        return targetAddressRightView
    }

    @objc func clearAction() {
        clearAddressFromResolvingEnsName()
        textFieldText = String()
    }

    @objc func pasteAction() {
        clearAddressFromResolvingEnsName()

        guard let value = UIPasteboard.general.string?.trimmed else {
            delegate?.displayError(error: SendInputErrors.emptyClipBoard, for: self)
            return
        }

        if CryptoAddressValidator.isValidAddress(value) {
            textFieldText = value

            let serverToResolveEns = RPCServer.main
            guard let address = AlphaWallet.Address(string: value) else {
                //Don't show an error when pasting what seems like a wrong ENS name for better usability
                self.addressOrEnsName = nil
                self.delegate?.didPaste(in: self)
                return
            }

            ENSReverseLookupCoordinator(server: serverToResolveEns).getENSNameFromResolver(forAddress: address) { [weak self] result in
                guard let strongSelf = self else { return }
                guard let resolvedESNname = result.value else {
                    //Don't show an error when pasting what seems like a wrong ENS name for better usability
                    strongSelf.addressOrEnsName = nil
                    strongSelf.delegate?.didPaste(in: strongSelf)
                    return
                }

                strongSelf.addressOrEnsName = .ensName(resolvedESNname)

                strongSelf.delegate?.didPaste(in: strongSelf)
            }

        } else if !value.contains(".") {
            delegate?.displayError(error: Errors.invalidAddress, for: self)
            return
        } else {
            textFieldText = value

            GetENSAddressCoordinator(server: serverToResolveEns).getENSAddressFromResolver(for: value) { [weak self] result in
                guard let strongSelf = self else { return }
                guard let address = result.value else {
                    //Don't show an error when pasting what seems like a wrong ENS name for better usability
                    strongSelf.addressOrEnsName = nil
                    strongSelf.delegate?.didPaste(in: strongSelf)
                    return
                }

                guard CryptoAddressValidator.isValidAddress(address.address) else {
                    strongSelf.delegate?.displayError(error: Errors.invalidAddress, for: strongSelf)
                    return
                }

                strongSelf.errorState = .none
                strongSelf.addressOrEnsName = .address(AlphaWallet.Address(address: address))

                strongSelf.delegate?.didPaste(in: strongSelf)
            }
        }
    }

    @objc func openReader() {
        delegate?.openQRCodeReader(for: self)
    }

    private func queueAddressResolution(ofValue value: String) {
        errorState = .none

        let value = value.trimmed
        guard value.isPossibleEnsName else { return }
        let oldTextValue = textField.text?.trimmed

        GetENSAddressCoordinator(server: serverToResolveEns).queueGetENSOwner(for: value) { [weak self] result in
            guard let strongSelf = self else { return }
            if let address = result.value {
                guard CryptoAddressValidator.isValidAddress(address.address) else {
                    //TODO good to show an error message in the UI/label that it is not a valid ENS name
                    return
                }

                guard oldTextValue == strongSelf.textField.text?.trimmed else { return }

                strongSelf.addressOrEnsName = .address(AlphaWallet.Address(address: address))
            }
        }
    }

    private func queueEnsResolution(ofValue addressString: String) {
        errorState = .none

        let serverToResolveEns = RPCServer.main
        guard let address = AlphaWallet.Address(string: addressString) else { return }
        let oldTextValue = textField.text?.trimmed

        ENSReverseLookupCoordinator(server: serverToResolveEns).getENSNameFromResolver(forAddress: address) { [weak self] result in
            guard let strongSelf = self else { return }
            guard let value = result.value, oldTextValue == strongSelf.textField.text?.trimmed else { return }

            strongSelf.addressOrEnsName = .ensName(value)
        }
    }

    private func clearAddressFromResolvingEnsName() {
        ensAddressLabel.text = nil
        ensAddressLabel.isHidden = true
    }

    override func resignFirstResponder() -> Bool {
        super.resignFirstResponder()
        return textField.resignFirstResponder()
    }
}

extension AddressTextField: UITextFieldDelegate {

    func textFieldDidEndEditing(_ textField: UITextField) {
        let borderColor = errorState.textFieldBorderColor(whileEditing: false)
        let shouldDropShadow = errorState.textFieldShowShadow(whileEditing: false)
        layer.borderColor = borderColor.cgColor
        backgroundColor = DataEntry.Color.textFieldBackground

        dropShadow(color: shouldDropShadow ? borderColor : .clear, radius: DataEntry.Metric.shadowRadius)
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        let borderColor = errorState.textFieldBorderColor(whileEditing: true)
        layer.borderColor = borderColor.cgColor
        backgroundColor = Colors.appWhite

        dropShadow(color: borderColor, radius: DataEntry.Metric.shadowRadius)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let delegate = delegate else { return true }
        return delegate.shouldReturn(in: self)
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        clearAddressFromResolvingEnsName()
        guard delegate != nil else { return true }
        let newValue = (self.textField.text as NSString?)?.replacingCharacters(in: range, with: string)
        if let newValue = newValue {
            if CryptoAddressValidator.isValidAddress(newValue) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    //Retain self because it's still useful to resolve and cache even if not used immediately
                    self.queueEnsResolution(ofValue: newValue)
                }
            } else if newValue.isPossibleEnsName {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    //Retain self because it's still useful to resolve and cache even if not used immediately
                    self.queueAddressResolution(ofValue: newValue)
                }
            }
        }

        informDelegateDidChange(to: newValue ?? "")
        return true
    }

    private func informDelegateDidChange(to string: String) {
        //DispatchQueue because the textfield hasn't been updated yet
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.delegate?.didChange(to: string, in: strongSelf)
        }
    }
}

extension String {
    fileprivate var isPossibleEnsName: Bool {
        let minimumEnsNameLength = 6 //We assume .co is possible in the future, so: a.b.co
        return count >= minimumEnsNameLength && contains(".")
    }
}
