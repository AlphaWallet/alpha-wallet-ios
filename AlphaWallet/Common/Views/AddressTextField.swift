// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

protocol AddressTextFieldDelegate: AnyObject {
    func displayError(error: Error, for textField: AddressTextField)
    func openQRCodeReader(for textField: AddressTextField)
    func didPaste(in textField: AddressTextField)
    func shouldReturn(in textField: AddressTextField) -> Bool
    func didChange(to string: String, in textField: AddressTextField)
    func doneButtonTapped(for textField: AddressTextField)
    func nextButtonTapped(for textField: AddressTextField)
}

extension AddressTextFieldDelegate {
    func doneButtonTapped(for textField: AddressTextField) {

    }

    func nextButtonTapped(for textField: AddressTextField) {

    }
}

final class AddressTextField: UIControl {
    private let domainResolutionService: DomainNameResolutionServiceType
    private let notifications = NotificationCenter.default
    private let server: RPCServer

    private lazy var textField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.delegate = self
        textField.leftViewMode = .always
        textField.rightViewMode = .always
        textField.layer.cornerRadius = DataEntry.Metric.TextField.Default.cornerRadius
        textField.leftView = .spacerWidth(16)
        textField.rightView = makeTargetAddressRightView()
        textField.layer.borderColor = Configuration.Color.Semantic.border.cgColor
        textField.layer.borderWidth = DataEntry.Metric.borderThickness
        textField.placeholder = R.string.localizable.addressEnsLabelMessage()
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.textColor = Configuration.Color.Semantic.defaultForegroundText
        textField.font = Configuration.Font.textField

        return textField
    }()
    private lazy var ensAddressLabel: AddressOrEnsNameLabel = {
        let label = AddressOrEnsNameLabel(domainResolutionService: domainResolutionService)
        label.addressFormat = .truncateMiddle
        label.shouldShowLoadingIndicator = true

        return label
    }()

    private var textFieldText: String {
        get { return textField.text ?? "" }
        set {
            textField.text = newValue

            let notification = Notification(name: UITextField.textDidChangeNotification, object: textField)
            NotificationCenter.default.post(notification)
        }
    }

    private (set) var pasteButton: Button = {
        let button = Button(size: .normal, style: .borderless)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(R.string.localizable.sendPasteButtonTitle(), for: .normal)
        button.titleLabel?.font = Configuration.Font.accessory
        button.setTitleColor(Configuration.Color.Semantic.icon, for: .normal)
        button.setBackgroundColor(Configuration.Color.Semantic.addressTextFieldPasteButtonBackground, forState: .normal)
        button.contentHorizontalAlignment = .right
        button.heightConstraint.flatMap { NSLayoutConstraint.deactivate([$0]) }
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.titleEdgeInsets = .zero
        button.contentEdgeInsets = .zero

        return button
    }()

    private var clearButton: Button = {
        let button = Button(size: .normal, style: .borderless)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(R.string.localizable.clearButtonTitle(), for: .normal)
        button.titleLabel?.font = Configuration.Font.accessory
        button.setTitleColor(Configuration.Color.Semantic.icon, for: .normal)
        button.setBackgroundColor(Configuration.Color.Semantic.addressTextFieldClearButtonBackground, forState: .normal)
        button.contentHorizontalAlignment = .right
        button.heightConstraint.flatMap { NSLayoutConstraint.deactivate([$0]) }
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.titleEdgeInsets = .zero
        button.contentEdgeInsets = .zero

        return button
    }()

    let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = Configuration.Font.textFieldTitle
        label.textColor = Configuration.Color.Semantic.defaultSubtitleText
        label.textAlignment = .left
        label.numberOfLines = 0

        return label
    }()

    let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.font = Configuration.Font.textFieldStatus
        label.textColor = Configuration.Color.Semantic.textFieldStatus
        label.textAlignment = .left

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
            //Guard against setting the value consecutively breaking UI state due to multiple resolution. This can happen when an EIP681 link is tapped in the browser to trigger a send fungible screen
            guard textFieldText != newValue else { return }

            //Client code sometimes sets back the address. We only set (and thus clear the ENS name) if it doesn't match the resolved address
            guard ensAddressLabel.stringValue != newValue else { return }
            textFieldText = newValue

            ensAddressResolve(value: newValue)
        }
    }

    var returnKeyType: UIReturnKeyType {
        get { return textField.returnKeyType }
        set { textField.returnKeyType = newValue }
    }

    var errorState: TextField.TextFieldErrorState = .none {
        didSet {
            switch errorState {
            case .error(let error):
                statusLabel.textColor = Configuration.Color.Semantic.textFieldStatus
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

    var inputAccessoryButtonType = TextField.InputAccessoryButtonType.none {
        didSet {
            switch inputAccessoryButtonType {
            case .done:
                textField.inputAccessoryView = UIToolbar.doneToolbarButton(#selector(doneButtonTapped), self)
            case .next:
                textField.inputAccessoryView = UIToolbar.nextToolbarButton(#selector(nextButtonTapped), self)
            case .none:
                textField.inputAccessoryView = nil
            }
        }
    }

    weak var delegate: AddressTextFieldDelegate?

    init(server: RPCServer, domainResolutionService: DomainNameResolutionServiceType, edgeInsets: UIEdgeInsets = DataEntry.Metric.AddressTextField.insets) {
        self.server = server
        self.domainResolutionService = domainResolutionService
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        pasteButton.addTarget(self, action: #selector(pasteButtonSelected), for: .touchUpInside)
        clearButton.addTarget(self, action: #selector(clearButtonSelected), for: .touchUpInside)

        addSubview(textField)

        updateClearAndPasteButtons(textFieldText)

        NSLayoutConstraint.activate([
            //NOTE: edgeInsets to make shadow non clipped, why?
            textField.anchorsConstraint(to: self, edgeInsets: edgeInsets),
            textField.heightAnchor.constraint(equalToConstant: DataEntry.Metric.TextField.Default.height),
        ])

        notifications.addObserver(self, selector: #selector(textDidChangeNotification), name: UITextField.textDidChangeNotification, object: nil)

        cornerRadius = DataEntry.Metric.TextField.Default.cornerRadius
        textField.layer.borderWidth = DataEntry.Metric.borderThickness
        textField.backgroundColor = Configuration.Color.Semantic.textFieldBackground
        textField.layer.borderColor = errorState.textFieldBorderColor(whileEditing: isFirstResponder).cgColor
        errorState = .none
    }

    //NOTE: maybe it's not a good name, but reasons using this function to extract default layout in separate function to prevent copying code
    private func defaultLayout() -> UIView {
        let controlsContainer = UIView()
        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        controlsContainer.backgroundColor = Configuration.Color.Semantic.addressTextFieldControlsContainerBackground

        let addressControlsStackView = [
            pasteButton,
            clearButton
        ].asStackView(axis: .horizontal)
        addressControlsStackView.translatesAutoresizingMaskIntoConstraints = false

        controlsContainer.addSubview(addressControlsStackView)

        let ensAddressView = [
            ensAddressLabel.loadingIndicator,
            ensAddressLabel.blockieImageView,
            ensAddressLabel,
            statusLabel
        ].asStackView(axis: .horizontal, spacing: 5, alignment: .center)

        let stackView = [
            self,
            .spacer(height: DataEntry.Metric.TextField.Default.spaceFromTextFieldToStatusLabel),
            [ensAddressView, .spacerWidth(4, flexible: true), controlsContainer].asStackView(axis: .horizontal, alignment: .center),
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            addressControlsStackView.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor),
            addressControlsStackView.topAnchor.constraint(equalTo: controlsContainer.topAnchor),
            addressControlsStackView.bottomAnchor.constraint(equalTo: controlsContainer.bottomAnchor),
            addressControlsStackView.leadingAnchor.constraint(greaterThanOrEqualTo: controlsContainer.leadingAnchor),
            controlsContainer.heightAnchor.constraint(equalToConstant: DataEntry.Metric.TextField.Default.controlsContainerHeight),
            controlsContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])

        return stackView
    }

    func defaultLayout(edgeInsets: UIEdgeInsets) -> UIView {
        let stackView = [
            label,
            .spacer(height: DataEntry.Metric.TextField.Default.spaceFromTitleToTextField),
            defaultLayout(),
        ].asStackView(axis: .vertical)

        stackView.translatesAutoresizingMaskIntoConstraints = false

        let view = UIView()
        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: view, edgeInsets: edgeInsets),
        ])

        return view
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

    private func makeTargetAddressRightView() -> UIView {
        let icon = R.image.qr_code_icon()!.withTintColor(Configuration.Color.Semantic.textFieldIcon, renderingMode: .alwaysTemplate)
        let scanQRCodeButton = Button(size: .normal, style: .system)
        scanQRCodeButton.translatesAutoresizingMaskIntoConstraints = false
        scanQRCodeButton.setImage(icon, for: .normal)
        scanQRCodeButton.addTarget(self, action: #selector(openReaderButtonSelected), for: .touchUpInside)
        scanQRCodeButton.setBackgroundColor(Configuration.Color.Semantic.addressTextFieldScanQRCodeButtonBackground, forState: .normal)
        //NOTE: Fix clipped shadow on textField (iPhone 5S)
        scanQRCodeButton.clipsToBounds = false
        scanQRCodeButton.layer.masksToBounds = false
        scanQRCodeButton.heightConstraint.flatMap { NSLayoutConstraint.deactivate([$0]) }
        let targetAddressRightView = [scanQRCodeButton].asStackView(distribution: .fill)
        targetAddressRightView.clipsToBounds = false
        targetAddressRightView.layer.masksToBounds = false
        targetAddressRightView.backgroundColor = Configuration.Color.Semantic.addressTextFieldTargetAddressRightViewBackground
        //As of iOS 13, we need to constrain the width of `rightView`
        let rightViewFittingSize = targetAddressRightView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        NSLayoutConstraint.activate([
            targetAddressRightView.heightAnchor.constraint(equalToConstant: ScreenChecker.size(big: 50, medium: 50, small: 35)),
            targetAddressRightView.widthAnchor.constraint(equalToConstant: rightViewFittingSize.width),
        ])
        targetAddressRightView.translatesAutoresizingMaskIntoConstraints = false

        return targetAddressRightView
    }

    @objc private func clearButtonSelected(_ sender: UIButton) {
        ensAddressLabel.clear()
        textFieldText = String()
        errorState = .none
    }

    @objc private func pasteButtonSelected(_ sender: UIButton) {
        if let value = UIPasteboard.general.string?.trimmed {
            textFieldText = value

            delegate?.didPaste(in: self)
            ensAddressLabel.resolve(value, server: server).done { [weak self] resolution in
                self?.addressOrEnsNameDidResolve(resolution, whileTextWasPaste: true)
            }.cauterize()
        } else {
            ensAddressLabel.clear()
            delegate?.displayError(error: SendInputErrors.emptyClipBoard, for: self)
        }
    }

    @objc func openReaderButtonSelected() {
        delegate?.openQRCodeReader(for: self)
    }

    @discardableResult override func resignFirstResponder() -> Bool {
        super.resignFirstResponder()
        return textField.resignFirstResponder()
    }

    @objc func doneButtonTapped() {
        delegate?.doneButtonTapped(for: self)
    }

    @objc func nextButtonTapped() {
        delegate?.nextButtonTapped(for: self)
    }
}

extension AddressTextField: UITextFieldDelegate {

    func textFieldDidEndEditing(_ textField: UITextField) {
        let borderColor = errorState.textFieldBorderColor(whileEditing: false)
        let shouldDropShadow = errorState.textFieldShowShadow(whileEditing: false)
        textField.layer.borderColor = borderColor.cgColor
        textField.backgroundColor = Configuration.Color.Semantic.textFieldBackground

        textField.dropShadow(color: shouldDropShadow ? borderColor : .clear, radius: DataEntry.Metric.shadowRadius)
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        let borderColor = errorState.textFieldBorderColor(whileEditing: true)
        textField.layer.borderColor = borderColor.cgColor
        textField.backgroundColor = Configuration.Color.Semantic.textFieldBackground

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
        ensAddressLabel.resolve(value, server: server).done { [weak self] resolution in
            self?.addressOrEnsNameDidResolve(resolution, whileTextWasPaste: false)
        }.cauterize()
    }

    private func addressOrEnsNameDidResolve(_ response: BlockieAndAddressOrEnsResolution, whileTextWasPaste: Bool) {
        guard value == textField.text?.trimmed else {
            return
        }

        switch response.resolution {
        case .invalidInput:
            if whileTextWasPaste {
                delegate?.displayError(error: InputError.invalidAddress, for: self)
            }
        case .resolved(let resolved):
            //NOTE: case .resolved(_) determines that entered address value is valid thus errorState should be .none
            errorState = .none

            if let addressOrEnsName = resolved {
                ensAddressLabel.addressOrEnsName = addressOrEnsName
                ensAddressLabel.set(blockieImage: response.image)
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

extension SendInputErrors: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptyClipBoard:
            return R.string.localizable.sendErrorEmptyClipBoard()
        case .wrongInput:
            return R.string.localizable.sendErrorWrongInput()
        }
    }
}
