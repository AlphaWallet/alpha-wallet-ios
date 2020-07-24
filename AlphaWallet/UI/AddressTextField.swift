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
    private let ensAddressLabel: AddressOrEnsNameLabel = {
        let label = AddressOrEnsNameLabel()
        label.addressFormat = .truncateMiddle
        label.shouldShowLoadingIndicator = true

        return label
    }()

    var ensAddressView: UIStackView {
        return [ensAddressLabel.loadingIndicator, ensAddressLabel, statusLabel].asStackView(axis: .horizontal, spacing: 5, alignment: .leading)
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
            if let ensResolvedAddress = ensAddressLabel.addressString/*addressString*/, !ensResolvedAddress.isEmpty {
                return ensResolvedAddress
            } else {
                return textFieldText
            }
        }
        set {
            //Client code sometimes sets back the address. We only set (and thus clear the ENS name) if it doesn't match the resolved address
            guard ensAddressLabel.stringValue != newValue else { return }
            textFieldText = newValue

            ensAddressResolve(value: newValue)
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

        textField.layer.cornerRadius = DataEntry.Metric.cornerRadius
        textField.leftView = .spacerWidth(16)
        textField.rightView = makeTargetAddressRightView()
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
        ensAddressLabel.clear()
        textFieldText = String()
        errorState = .none
    }

    @objc func pasteAction() {
        if let value = UIPasteboard.general.string?.trimmed {
            textFieldText = value

            delegate?.didPaste(in: self)

            ensAddressLabel.resolve(value) { [weak self] resolution in
                self?.addressOrEnsNameDidResolve(resolution, whileTextWasPaste: true)
            }
        } else {
            ensAddressLabel.clear()
            delegate?.displayError(error: SendInputErrors.emptyClipBoard, for: self)
        }
    }

    @objc func openReader() {
        delegate?.openQRCodeReader(for: self)
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
        ensAddressLabel.clear()

        guard delegate != nil else { return true }
        let newValue = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.ensAddressResolve(value: newValue)
        }

        informDelegateDidChange(to: newValue)
        return true
    }

    private func ensAddressResolve(value: String) {
        ensAddressLabel.resolve(value) { [weak self] resolution in
            self?.addressOrEnsNameDidResolve(resolution, whileTextWasPaste: false)
        }
    }

    private func addressOrEnsNameDidResolve(_ resolution: AddressOrEnsNameLabel.AddressOrEnsResolution, whileTextWasPaste: Bool) {
        guard value == textField.text?.trimmed else {
            return
        }

        switch resolution {
        case .invalidInput:
            if whileTextWasPaste {
                delegate?.displayError(error: Errors.invalidAddress, for: self)
            }
        case .resolved(let resolved):
            if let addressOrEnsName = resolved {
                errorState = .none
                ensAddressLabel.addressOrEnsName = addressOrEnsName
            } else {
                ensAddressLabel.clear()
            }

            if whileTextWasPaste {
                delegate?.didPaste(in: self)
            }
        }
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
