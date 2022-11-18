// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol TextViewDelegate: AnyObject {
    func shouldReturn(in textView: TextView) -> Bool
    func doneButtonTapped(for textView: TextView)
    func nextButtonTapped(for textView: TextView)
    func didChange(inTextView textView: TextView)
    func didPaste(in textView: TextView)
}

extension TextViewDelegate {
    func didChange(inTextView textView: TextView) { }
    func doneButtonTapped(for textView: TextView) { }
    func nextButtonTapped(for textView: TextView) { }
}

class TextView: UIControl {
    private let notifications = NotificationCenter.default

    let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()
    lazy var textView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = self
        textView.textContainerInset = .init(top: 10, left: 12, bottom: 10, right: 12)

        return textView
    }()

    let label = UILabel()
    var value: String {
        get { return textView.text ?? "" }
        set {
            textView.text = newValue
            let notification = Notification(name: UITextView.textDidChangeNotification, object: textView)
            notifications.post(notification)
        }
    }

    var inputAccessoryButtonType = TextField.InputAccessoryButtonType.none {
        didSet {
            switch inputAccessoryButtonType {
            case .done:
                textView.inputAccessoryView = UIToolbar.doneToolbarButton(#selector(doneButtonSelected), self)
            case .next:
                textView.inputAccessoryView = UIToolbar.doneToolbarButton(#selector(nextButtonSelected), self)
            case .none:
                textView.inputAccessoryView = nil
            }
        }
    }

    var pasteAndClearHidden: Bool {
        get { addressControlsContainer.isHidden }
        set { addressControlsContainer.isHidden = newValue }
    }

    var statusHidden: Bool {
        get { statusContainerView.isHidden }
        set { statusContainerView.isHidden = newValue }
    }

    var returnKeyType: UIReturnKeyType {
        get { return textView.returnKeyType }
        set { textView.returnKeyType = newValue }
    }

    var errorState: TextField.TextFieldErrorState = .none {
        didSet {
            switch errorState {
            case .error(let error):
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

    private var pasteButton: Button = {
        let button = Button(size: .normal, style: .borderless)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(R.string.localizable.sendPasteButtonTitle(), for: .normal)
        button.titleLabel?.font = DataEntry.Font.accessory
        button.setTitleColor(DataEntry.Color.icon, for: .normal)
        button.setBackgroundColor(.clear, forState: .normal)
        button.contentHorizontalAlignment = .right
        button.heightConstraint.flatMap { NSLayoutConstraint.deactivate([$0]) }
        button.contentEdgeInsets = .zero

        return button
    }()

    private var clearButton: Button = {
        let button = Button(size: .normal, style: .borderless)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(R.string.localizable.clearButtonTitle(), for: .normal)
        button.titleLabel?.font = DataEntry.Font.accessory
        button.setTitleColor(DataEntry.Color.icon, for: .normal)
        button.setBackgroundColor(.clear, forState: .normal)
        button.contentHorizontalAlignment = .right
        button.heightConstraint.flatMap { NSLayoutConstraint.deactivate([$0]) }
        button.contentEdgeInsets = .zero

        return button
    }()

    private var statusContainerView: UIStackView {
        return [statusLabel].asStackView(axis: .horizontal, spacing: 5, alignment: .leading)
    }

    private lazy var addressControlsContainer: UIView = {
        let addressControlsContainer = UIView()
        addressControlsContainer.translatesAutoresizingMaskIntoConstraints = false
        addressControlsContainer.backgroundColor = .clear

        let addressControlsStackView = [
            pasteButton,
            clearButton
        ].asStackView(axis: .horizontal)
        addressControlsStackView.translatesAutoresizingMaskIntoConstraints = false

        addressControlsContainer.addSubview(addressControlsStackView)

        NSLayoutConstraint.activate([
            addressControlsStackView.trailingAnchor.constraint(equalTo: addressControlsContainer.trailingAnchor),
            addressControlsStackView.topAnchor.constraint(equalTo: addressControlsContainer.topAnchor),
            addressControlsStackView.bottomAnchor.constraint(equalTo: addressControlsContainer.bottomAnchor),
            addressControlsStackView.leadingAnchor.constraint(greaterThanOrEqualTo: addressControlsContainer.leadingAnchor),
            addressControlsContainer.heightAnchor.constraint(equalToConstant: 30),
        ])

        return addressControlsContainer
    }()

    private var isConfigured = false

    weak var delegate: TextViewDelegate?

    init() {
        super.init(frame: .zero)
        pasteButton.addTarget(self, action: #selector(pasteButtonSelected), for: .touchUpInside)
        clearButton.addTarget(self, action: #selector(clearButtonSelected), for: .touchUpInside)
        translatesAutoresizingMaskIntoConstraints = false

        updateClearAndPasteButtons(value)

        addSubview(textView)

        NSLayoutConstraint.activate([
            textView.anchorsConstraint(to: self),
        ])

        notifications.addObserver(self, selector: #selector(textDidChangeNotification), name: UITextView.textDidChangeNotification, object: nil)
    }

    @objc private func clearButtonSelected(_ sender: UIButton) {
        value = String()
        errorState = .none
    }

    //NOTE: maybe it's not a good name, but reasons using this function to extract default layout in separate function to prevent copying code
    func defaultLayout() -> UIView {
        let stackView = [
            label,
            .spacer(height: DataEntry.Metric.TextField.Default.spaceFromTitleToTextField),
            self,
            .spacer(height: DataEntry.Metric.TextField.Default.spaceFromTitleToTextField),
            [statusContainerView, addressControlsContainer].asStackView(axis: .horizontal),
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        return stackView
    }

    @objc private func textDidChangeNotification(_ notification: Notification) {
        guard textView == notification.object as? UITextView, let text = textView.text else {
            return
        }

        updateClearAndPasteButtons(text)
    }

    private func updateClearAndPasteButtons(_ text: String) {
        clearButton.isHidden = text.isEmpty
        pasteButton.isHidden = !text.isEmpty
    }

    func configureOnce() {
        guard !isConfigured else { return }
        isConfigured = true

        label.font = DataEntry.Font.textFieldTitle
        label.textColor = DataEntry.Color.label

        statusLabel.font = DataEntry.Font.textFieldStatus
        statusLabel.textColor = DataEntry.Color.textFieldStatus

        textView.textColor = Configuration.Color.Semantic.defaultForegroundText
        textView.font = DataEntry.Font.text
        textView.layer.borderColor = DataEntry.Color.border.cgColor
        textView.layer.borderWidth = DataEntry.Metric.borderThickness
        textView.layer.cornerRadius = DataEntry.Metric.cornerRadius

        cornerRadius = DataEntry.Metric.cornerRadius
        layer.borderWidth = DataEntry.Metric.borderThickness
        backgroundColor = Configuration.Color.Semantic.textViewBackground
        textView.backgroundColor = .clear
        layer.borderColor = errorState.textFieldBorderColor(whileEditing: isFirstResponder).cgColor
        errorState = .none
    }

    @objc private func pasteButtonSelected(_ sender: UIButton) {
        guard let pastedText = UIPasteboard.general.string?.trimmed else { return }
        value = pastedText
        delegate?.didPaste(in: self)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
        return textView.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        super.becomeFirstResponder()
        return textView.resignFirstResponder()
    }

    @objc private func doneButtonSelected() {
        delegate?.doneButtonTapped(for: self)
    }

    @objc private func nextButtonSelected() {
        delegate?.nextButtonTapped(for: self)
    }
}

extension TextView: UITextViewDelegate {

    func textViewDidBeginEditing(_ textView: UITextView) {
        let borderColor = errorState.textFieldBorderColor(whileEditing: true)
        layer.borderColor = borderColor.cgColor
        backgroundColor = Configuration.Color.Semantic.textViewBackground

        dropShadow(color: borderColor, radius: DataEntry.Metric.shadowRadius)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        let borderColor = errorState.textFieldBorderColor(whileEditing: false)
        let shouldDropShadow = errorState.textFieldShowShadow(whileEditing: false)
        layer.borderColor = borderColor.cgColor
        backgroundColor = Configuration.Color.Semantic.textViewBackground

        dropShadow(color: shouldDropShadow ? borderColor : .clear, radius: DataEntry.Metric.shadowRadius)
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            guard let delegate = delegate else { return true }
            return delegate.shouldReturn(in: self)
        } else {
            return true
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        delegate?.didChange(inTextView: self)
    }
}

extension TextView {
    static var defaultTextView: TextView {
        let textView = TextView()
        textView.configureOnce()

        return textView
    }

    static var nonEditableTextView: TextView {
        let textView = TextView.defaultTextView
        textView.textView.isEditable = false
        textView.textView.isScrollEnabled = false
        textView.textView.isSelectable = true
        textView.textView.spellCheckingType = .no
        textView.textView.autocorrectionType = .no
        textView.pasteAndClearHidden = true
        textView.statusHidden = true

        return textView
    }
}
