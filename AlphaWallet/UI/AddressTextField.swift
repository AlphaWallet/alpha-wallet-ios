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
            
            let notification = Notification(name: UITextField.textDidChangeNotification, object: textField)
            NotificationCenter.default.post(notification)
            
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
        updateClearAndPasteButtons(textField.text ?? "")
        
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
        ensAddressLabel.isHidden = true
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
    
    var pasteButton: Button = {
        let button = Button(size: .normal, style: .borderless)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(R.string.localizable.sendPasteButtonTitle(), for: .normal)
        button.titleLabel?.font = DataEntry.Font.accessory
        button.setTitleColor(DataEntry.Color.icon, for: .normal)
        button.addTarget(self, action: #selector(pasteAction), for: .touchUpInside)
        button.backgroundColor = .clear
        button.contentHorizontalAlignment = .right
        return button
    }()
    
    var clearButton: Button = {
        let button = Button(size: .normal, style: .borderless)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Clear", for: .normal)
        button.titleLabel?.font = DataEntry.Font.accessory
        button.setTitleColor(DataEntry.Color.icon, for: .normal)
        button.addTarget(self, action: #selector(clearAction), for: .touchUpInside)
        button.backgroundColor = .clear
        button.contentHorizontalAlignment = .right
        return button
    }()
    
    var addresBookButton: Button = {
        let button = Button(size: .normal, style: .borderless)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(R.string.localizable.sendPasteButtonAddressBook(), for: .normal)
        button.titleLabel?.font = DataEntry.Font.accessory
        button.setTitleColor(DataEntry.Color.icon, for: .normal)
        button.addTarget(self, action: #selector(addressBookAction), for: .touchUpInside)
        button.backgroundColor = .clear
        button.contentHorizontalAlignment = .right
        
        return button
    }()
    
    private func makeTargetAddressRightView() -> UIView {
        let scanQRCodeButton = Button(size: .normal, style: .borderless)
        scanQRCodeButton.translatesAutoresizingMaskIntoConstraints = false
        scanQRCodeButton.setImage(R.image.qr_code_icon(), for: .normal)
        scanQRCodeButton.addTarget(self, action: #selector(openReader), for: .touchUpInside)
        scanQRCodeButton.backgroundColor = .clear
        
        let targetAddressRightView = [scanQRCodeButton].asStackView(distribution: .fill)
        //As of iOS 13, we need to constrain the width of `rightView`
        let rightViewFittingSize = targetAddressRightView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        NSLayoutConstraint.activate([
            targetAddressRightView.widthAnchor.constraint(equalToConstant: rightViewFittingSize.width),
        ])
        targetAddressRightView.translatesAutoresizingMaskIntoConstraints = false

        return targetAddressRightView
    }

    @objc func addressBookAction() {
        
    }
    
    @objc func clearAction() {
        textField.text?.removeAll()
        clearAddressFromResolvingEnsName()
        
        let notification = Notification(name: UITextField.textDidChangeNotification, object: textField)
        NotificationCenter.default.post(notification)
    }
    
    @objc func pasteAction() {
        clearAddressFromResolvingEnsName()
        
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
            let notification = Notification(name: UITextField.textDidChangeNotification, object: textField)
            NotificationCenter.default.post(notification)
            
            GetENSAddressCoordinator(server: serverToResolveEns).getENSAddressFromResolver(for: value) { result in
                guard let address = result.value else {
                    //Don't show an error when pasting what seems like a wrong ENS name for better usability
                    self.delegate?.didPaste(in: self)
                    return
                }
                
                guard CryptoAddressValidator.isValidAddress(address.address) else {
                    self.delegate?.displayError(error: Errors.invalidAddress, for: self)
                    return
                }
                
                self.errorState = .none
                self.ensAddressLabel.isHidden = false
                self.ensAddressLabel.text = address.address
                
                self.delegate?.didPaste(in: self)
            }
        }
    }

    @objc func openReader() {
        delegate?.openQRCodeReader(for: self)
    }

    func queueEnsResolution(ofValue value: String) {
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
                strongSelf.ensAddressLabel.isHidden = false
                strongSelf.ensAddressLabel.text = address.address
            }
        }
    }

    private func clearAddressFromResolvingEnsName() {
        ensAddressLabel.text = nil
        ensAddressLabel.isHidden = true
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
        backgroundColor = DataEntry.Color.textFieldBackgroundWhileEditing
        
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
        if let newValue = newValue, !CryptoAddressValidator.isValidAddress(newValue) {
            if newValue.isPossibleEnsName {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    //Retain self because it's still useful to resolve and cache even if not used immediately
                    self.queueEnsResolution(ofValue: newValue)
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
