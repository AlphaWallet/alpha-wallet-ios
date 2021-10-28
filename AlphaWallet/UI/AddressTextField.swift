// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol AddressTextFieldDelegate: AnyObject {
    func displayError(error: Error, for textField: AddressTextField)
    func openQRCodeReader(for textField: AddressTextField)
    func didPaste(in textField: AddressTextField)
    func shouldReturn(in textField: AddressTextField) -> Bool
    func didChange(to string: String, in textField: AddressTextField)
}

class AddressTextField: UIControl {
    private let notifications = NotificationCenter.default
    private var isConfigured = false
    private let textField = UITextField()
    private let ensAddressLabel: AddressOrEnsNameLabel = {
        let label = AddressOrEnsNameLabel()
        label.addressFormat = .truncateMiddle
        label.shouldShowLoadingIndicator = true

        return label
    }()

    lazy var ensAddressView: UIStackView = {
        return [
            ensAddressLabel.loadingIndicator,
            ensAddressLabel.blockieImageView,
            ensAddressLabel,
            statusLabel
        ].asStackView(axis: .horizontal, spacing: 5, alignment: .center)
    }()

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
        button.heightConstraint.flatMap { NSLayoutConstraint.deactivate([$0]) }
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.titleEdgeInsets = .zero
        button.contentEdgeInsets = .zero

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
        button.heightConstraint.flatMap { NSLayoutConstraint.deactivate([$0]) }
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.titleEdgeInsets = .zero
        button.contentEdgeInsets = .zero

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
            if let ensResolvedAddress = ensAddressLabel.addressString, !ensResolvedAddress.isEmpty {
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

            textField.layer.borderColor = borderColor.cgColor
            textField.dropShadow(color: shouldDropShadow ? borderColor : .clear, radius: DataEntry.Metric.shadowRadius)
        }
    }

    weak var delegate: AddressTextFieldDelegate?

    init(edgeInsets: UIEdgeInsets = DataEntry.Metric.AddressTextField.insets) {
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
            textField.anchorsConstraint(to: self, edgeInsets: edgeInsets),
            heightAnchor.constraint(equalToConstant: ScreenChecker().isNarrowScreen ? 30 : 50),
        ])

        notifications.addObserver(self,
            selector: #selector(textDidChangeNotification),
            name: UITextField.textDidChangeNotification, object: nil)
    }
    //NOTE: maybe it's not a good name, but reasons using this function to extract default layout in separate function to prevent copying code
    func defaultLayout() -> UIView {
        let addressControlsContainer = UIView()
        addressControlsContainer.translatesAutoresizingMaskIntoConstraints = false
        addressControlsContainer.backgroundColor = .clear

        let addressControlsStackView = [
            pasteButton,
            clearButton
        ].asStackView(axis: .horizontal)
        addressControlsStackView.translatesAutoresizingMaskIntoConstraints = false

        addressControlsContainer.addSubview(addressControlsStackView)

        let stackView = [
            self, .spacer(height: 4), [
                ensAddressView,
                .spacerWidth(4, flexible: true),
                addressControlsContainer
            ].asStackView(axis: .horizontal, alignment: .center),
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            addressControlsStackView.trailingAnchor.constraint(equalTo: addressControlsContainer.trailingAnchor),
            addressControlsStackView.topAnchor.constraint(equalTo: addressControlsContainer.topAnchor),
            addressControlsStackView.bottomAnchor.constraint(equalTo: addressControlsContainer.bottomAnchor),
            addressControlsStackView.leadingAnchor.constraint(greaterThanOrEqualTo: addressControlsContainer.leadingAnchor),
            addressControlsContainer.heightAnchor.constraint(equalToConstant: 30),
            addressControlsContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])

        return stackView
    }

    func defaultLayout(edgeInsets: UIEdgeInsets) -> UIView {
        let stackView = [
            .spacer(height: edgeInsets.top),
            label,
            .spacer(height: 4),
            defaultLayout(),
            .spacer(height: edgeInsets.bottom),
        ].asStackView(axis: .vertical)

        return [.spacerWidth(edgeInsets.left), stackView, .spacerWidth(edgeInsets.right)].asStackView(axis: .horizontal)
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
        return nil
    }

    @discardableResult override func becomeFirstResponder() -> Bool {
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

        textField.layer.borderWidth = DataEntry.Metric.borderThickness
        textField.backgroundColor = DataEntry.Color.textFieldBackground
        textField.layer.borderColor = errorState.textFieldBorderColor(whileEditing: isFirstResponder).cgColor
        errorState = .none
    }

    private func makeTargetAddressRightView() -> UIView {
        let scanQRCodeButton = Button(size: .normal, style: .system)
        scanQRCodeButton.translatesAutoresizingMaskIntoConstraints = false
        scanQRCodeButton.setImage(R.image.qr_code_icon(), for: .normal)
        scanQRCodeButton.addTarget(self, action: #selector(openReader), for: .touchUpInside)
        scanQRCodeButton.setBackgroundColor(.clear, forState: .normal)
        //NOTE: Fix clipped shadow on textField (iPhone 5S)
        scanQRCodeButton.clipsToBounds = false
        scanQRCodeButton.layer.masksToBounds = false
        scanQRCodeButton.heightConstraint.flatMap { NSLayoutConstraint.deactivate([$0]) }
        let targetAddressRightView = [scanQRCodeButton].asStackView(distribution: .fill)
        targetAddressRightView.clipsToBounds = false
        targetAddressRightView.layer.masksToBounds = false
        targetAddressRightView.backgroundColor = .clear
        //As of iOS 13, we need to constrain the width of `rightView`
        let rightViewFittingSize = targetAddressRightView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        NSLayoutConstraint.activate([
            targetAddressRightView.heightAnchor.constraint(equalToConstant: ScreenChecker().isNarrowScreen ? 30 : 50),
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
            ensAddressLabel.resolve(value).done { [weak self] resolution in
                self?.addressOrEnsNameDidResolve(resolution, whileTextWasPaste: true)
            }.cauterize()
        } else {
            ensAddressLabel.clear()
            delegate?.displayError(error: SendInputErrors.emptyClipBoard, for: self)
        }
    }

    @objc func openReader() {
        delegate?.openQRCodeReader(for: self)
    }

    @discardableResult override func resignFirstResponder() -> Bool {
        super.resignFirstResponder()
        return textField.resignFirstResponder()
    }
}

extension AddressTextField: UITextFieldDelegate {

    func textFieldDidEndEditing(_ textField: UITextField) {
        let borderColor = errorState.textFieldBorderColor(whileEditing: false)
        let shouldDropShadow = errorState.textFieldShowShadow(whileEditing: false)
        textField.layer.borderColor = borderColor.cgColor
        textField.backgroundColor = DataEntry.Color.textFieldBackground

        textField.dropShadow(color: shouldDropShadow ? borderColor : .clear, radius: DataEntry.Metric.shadowRadius)
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        let borderColor = errorState.textFieldBorderColor(whileEditing: true)
        textField.layer.borderColor = borderColor.cgColor
        textField.backgroundColor = Colors.appWhite

        textField.dropShadow(color: borderColor, radius: DataEntry.Metric.shadowRadius)
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
        ensAddressLabel.resolve(value).done { [weak self] resolution in
            self?.addressOrEnsNameDidResolve(resolution, whileTextWasPaste: false)
        }.cauterize()
    }

    private func addressOrEnsNameDidResolve(_ response: AddressOrEnsNameLabel.BlockieAndAddressOrEnsResolution, whileTextWasPaste: Bool) {
        guard value == textField.text?.trimmed else {
            return
        }

        switch response.resolution {
        case .invalidInput:
            if whileTextWasPaste {
                delegate?.displayError(error: Errors.invalidAddress, for: self)
            }
        case .resolved(let resolved):
            //NOTE: case .resolved(_) determines that entered address value is valid thus errorState should be .none
            errorState = .none

            if let addressOrEnsName = resolved {
                ensAddressLabel.addressOrEnsName = addressOrEnsName
                ensAddressLabel.blockieImage = response.image
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
