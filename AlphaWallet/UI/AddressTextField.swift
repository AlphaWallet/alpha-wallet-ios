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

        NSLayoutConstraint.activate([
            textField.anchorsConstraint(to: self),
            heightAnchor.constraint(equalToConstant: ScreenChecker().isNarrowScreen ? 30 : 50),
        ])
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

        label.font = DataEntry.Font.label
        label.textColor = DataEntry.Color.label

        ensAddressLabel.font = DataEntry.Font.label
        ensAddressLabel.textColor = DataEntry.Color.label

        textField.layer.cornerRadius = DataEntry.Metric.cornerRadius
        textField.leftView = .spacerWidth(22)
        textField.rightView = makeTargetAddressRightView()
        textField.textColor = DataEntry.Color.text
        textField.font = Fonts.regular(size: ScreenChecker().isNarrowScreen ? 10: 13)
        textField.layer.borderColor = DataEntry.Color.border.cgColor
        textField.layer.borderWidth = DataEntry.Metric.borderThickness
        textField.placeholder = R.string.localizable.addressEnsLabelMessage()
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
    }

    private func makeTargetAddressRightView() -> UIView {
        let pasteButton = Button(size: .normal, style: .borderless)
        pasteButton.translatesAutoresizingMaskIntoConstraints = false
        pasteButton.setTitle(R.string.localizable.sendPasteButtonTitle(), for: .normal)
        pasteButton.titleLabel?.font = DataEntry.Font.accessory
        pasteButton.setTitleColor(DataEntry.Color.secondary, for: .normal)
        pasteButton.addTarget(self, action: #selector(pasteAction), for: .touchUpInside)

        let scanQRCodeButton = Button(size: .normal, style: .borderless)
        scanQRCodeButton.translatesAutoresizingMaskIntoConstraints = false
        scanQRCodeButton.setImage(R.image.qr_code_icon()?.withRenderingMode(.alwaysTemplate), for: .normal)
        scanQRCodeButton.imageView?.tintColor = DataEntry.Color.icon
        scanQRCodeButton.addTarget(self, action: #selector(openReader), for: .touchUpInside)

        let targetAddressRightView = [pasteButton, scanQRCodeButton].asStackView(distribution: .equalSpacing)
        //As of iOS 13, we need to constrain the width of `rightView`
        let rightViewFittingSize = targetAddressRightView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        NSLayoutConstraint.activate([
            targetAddressRightView.widthAnchor.constraint(equalToConstant: rightViewFittingSize.width),
        ])
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
            GetENSAddressCoordinator(server: serverToResolveEns).getENSAddressFromResolver(for: value) { result in
                guard let address = result.value else {
                    //Don't show an error when pasting what seems like a wrong ENS name for better usability
                    return
                }
                guard CryptoAddressValidator.isValidAddress(address.address) else {
                    self.delegate?.displayError(error: Errors.invalidAddress, for: self)
                    return
                }
                self.ensAddressLabel.text = address.address
                self.delegate?.didPaste(in: self)
            }
        }
    }

    @objc func openReader() {
        delegate?.openQRCodeReader(for: self)
    }

    func queueEnsResolution(ofValue value: String) {
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
                strongSelf.ensAddressLabel.text = address.address
            }
        }
    }

    private func clearAddressFromResolvingEnsName() {
        ensAddressLabel.text = nil
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
