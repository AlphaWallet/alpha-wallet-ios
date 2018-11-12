// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol AddressTextFieldDelegate: class {
    func displayError(error: Error, for textField: AddressTextField)
    func openQRCodeReader(for textField: AddressTextField)
    func didPaste(in textField: AddressTextField)
    func shouldReturn(in textField: AddressTextField) -> Bool
    func shouldChange(in range: NSRange, to string: String, in textField: AddressTextField) -> Bool
}

class AddressTextField: UIControl {

    private var isConfigured = false
    private let textField = UITextField()
    let ensLabel = UILabel()

    var value: String {
        get {
            return textField.text ?? ""
        }
        set {
            textField.text = newValue
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

        ensLabel.translatesAutoresizingMaskIntoConstraints = false
        ensLabel.numberOfLines = 0
        ensLabel.textColor = Colors.appGrayLabelColor
        ensLabel.font = Fonts.regular(size: 10)!
        ensLabel.textAlignment = .center

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

        ensLabel.font = Fonts.regular(size: 10)!
        ensLabel.textColor = Colors.appGrayLabelColor

        textField.leftView = .spacerWidth(22)
        textField.rightView = makeTargetAddressRightView()
        textField.textColor = Colors.appText
        textField.font = ScreenChecker().isNarrowScreen() ? Fonts.light(size: 11)! : Fonts.light(size: 15)!
        textField.layer.borderColor = Colors.appBackground.cgColor
        textField.layer.borderWidth = 1
        textField.placeholder = "Ethereum address or ENS name"
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
        //if address is pasted, the GetENSOwnerCoordinator will simply return it back in EthereumAddress format
        GetENSOwnerCoordinator(config: Config()).getENSOwner(for: value) { result in
            if let address = result.value {
                guard CryptoAddressValidator.isValidAddress(address.address) else {
                    self.delegate?.displayError(error: Errors.invalidAddress, for: self)
                    return
                }
                self.ensLabel.text = value
                self.value = address.address
                self.delegate?.didPaste(in: self)
            } else {
                self.delegate?.displayError(error: result.error?.error ?? Errors.invalidAddress, for: self)
            }
        }
    }

    @objc func openReader() {
        delegate?.openQRCodeReader(for: self)
    }
}

extension AddressTextField: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let delegate = delegate else { return true }
        return delegate.shouldReturn(in: self)
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let delegate = delegate else { return true }
        return delegate.shouldChange(in: range, to: string, in: self)
    }
}
