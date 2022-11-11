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
    private lazy var statusLabelContainerView: UIView = [statusLabel].asStackView(axis: .horizontal, spacing: 5, alignment: .leading)
    private lazy var clearAndPasteContainerView: UIView = {
        let clearAndPastControlsContainer = UIView()
        clearAndPastControlsContainer.translatesAutoresizingMaskIntoConstraints = false
        clearAndPastControlsContainer.backgroundColor = .clear

        return clearAndPastControlsContainer
    }()

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

    let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DataEntry.Font.textFieldStatus
        label.textColor = DataEntry.Color.textFieldStatus

        return label
    }()

    lazy var textView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = self
        textView.textContainerInset = .init(top: 10, left: 12, bottom: 10, right: 12)
        textView.textColor = Configuration.Color.Semantic.defaultForegroundText
        textView.font = DataEntry.Font.text
        textView.layer.borderColor = DataEntry.Color.border.cgColor
        textView.layer.borderWidth = DataEntry.Metric.borderThickness
        textView.layer.cornerRadius = DataEntry.Metric.cornerRadius
        textView.backgroundColor = .clear

        return textView
    }()

    let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DataEntry.Font.textFieldTitle
        label.textColor = DataEntry.Color.label

        return label
    }()

    var value: String {
        get { return textView.text ?? "" }
        set {
            textView.text = newValue
            notifications.post(Notification(name: UITextView.textDidChangeNotification, object: textView))
        }
    }
    
    var inputAccessoryButtonType = TextField.InputAccessoryButtonType.none {
        didSet {
            switch inputAccessoryButtonType {
            case .done:
                textView.inputAccessoryView = UIToolbar.doneToolbarButton(#selector(doneButtonTapped), self)
            case .next:
                textView.inputAccessoryView = UIToolbar.nextToolbarButton(#selector(nextButtonTapped), self)
            case .none:
                textView.inputAccessoryView = nil
            }
        }
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

    var isClearAndPasteHidden: Bool {
        get { return clearAndPasteContainerView.isHidden }
        set { clearAndPasteContainerView.isHidden = newValue }
    }

    var isStatusLabelHidden: Bool {
        get { return statusLabelContainerView.isHidden }
        set { statusLabelContainerView.isHidden = newValue }
    }

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

        cornerRadius = DataEntry.Metric.cornerRadius
        layer.borderWidth = DataEntry.Metric.borderThickness
        backgroundColor = Configuration.Color.Semantic.textViewBackground
        layer.borderColor = errorState.textFieldBorderColor(whileEditing: isFirstResponder).cgColor
        errorState = .none
    }

    @objc func clearButtonSelected(_ sender: UIButton) {
        value = String()
        errorState = .none
    }

    //NOTE: maybe it's not a good name, but reasons using this function to extract default layout in separate function to prevent copying code
    func defaultLayout(edgeInsets: UIEdgeInsets = .zero) -> UIView {
        let addressControlsStackView = [
            pasteButton,
            clearButton
        ].asStackView(axis: .horizontal)
        addressControlsStackView.translatesAutoresizingMaskIntoConstraints = false

        clearAndPasteContainerView.addSubview(addressControlsStackView)

        let stackView = [
            label,
            .spacer(height: DataEntry.Metric.TextField.Default.spaceFromTitleToTextField),
            [.spacerWidth(DataEntry.Metric.shadowRadius), self, .spacerWidth(DataEntry.Metric.shadowRadius)].asStackView(axis: .horizontal),
            .spacer(height: DataEntry.Metric.TextField.Default.spaceFromTitleToTextField),
            [statusLabelContainerView, clearAndPasteContainerView].asStackView(axis: .horizontal),
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            addressControlsStackView.trailingAnchor.constraint(equalTo: clearAndPasteContainerView.trailingAnchor),
            addressControlsStackView.topAnchor.constraint(equalTo: clearAndPasteContainerView.topAnchor),
            addressControlsStackView.bottomAnchor.constraint(equalTo: clearAndPasteContainerView.bottomAnchor),
            addressControlsStackView.leadingAnchor.constraint(greaterThanOrEqualTo: clearAndPasteContainerView.leadingAnchor),
            clearAndPasteContainerView.heightAnchor.constraint(equalToConstant: 30),
        ])

        let view = UIView()
        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        view.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalTo: stackView.heightAnchor),
            stackView.anchorsConstraint(to: view, edgeInsets: edgeInsets)
        ])

        return view
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

    @objc private func pasteButtonSelected(_ sender: UIButton) {
        if let pastedText = UIPasteboard.general.string?.trimmed {
            value = pastedText
            delegate?.didPaste(in: self)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
        return textView.becomeFirstResponder()
    }

    @objc private func doneButtonTapped() {
        delegate?.doneButtonTapped(for: self)
    }

    @objc private func nextButtonTapped() {
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

    public func textViewDidChange(_ textView: UITextView) {
        delegate?.didChange(inTextView: self)
    }
}
