// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol TextViewDelegate: class {
    func shouldReturn(in textView: TextView) -> Bool
    func doneButtonTapped(for textView: TextView)
    func nextButtonTapped(for textView: TextView)
    func didChange(inTextView textView: TextView)
}

extension TextViewDelegate {
    func didChange(inTextView textView: TextView) {
        //do nothing
    }
}

class TextView: UIControl {
    enum InputAccessoryButtonType {
        case done
        case next
        case none
    }

    let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }()
    let textView = UITextView()
    let label = UILabel()
    var value: String {
        get {
            return textView.text ?? ""
        }
        set {
            textView.text = newValue
        }
    }
    var inputAccessoryButtonType = InputAccessoryButtonType.none {
        didSet {
            switch inputAccessoryButtonType {
            case .done:
                textView.inputAccessoryView = makeToolbarWithDoneButton()
            case .next:
                textView.inputAccessoryView = makeToolbarWithNextButton()
            case .none:
                textView.inputAccessoryView = nil
            }
        }
    }

    var returnKeyType: UIReturnKeyType {
        get {
            return textView.returnKeyType
        }
        set {
            textView.returnKeyType = newValue
        }
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

    private var isConfigured = false
    weak var delegate: TextViewDelegate?

    init() {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = self
        textView.textContainerInset = .init(top: 10, left: 12, bottom: 10, right: 12)
        addSubview(textView)

        NSLayoutConstraint.activate([
            textView.anchorsConstraint(to: self),
        ])
    }

    func configureOnce() {
        guard !isConfigured else { return }
        isConfigured = true

        label.font = DataEntry.Font.textFieldTitle
        label.textColor = DataEntry.Color.label

        statusLabel.font = DataEntry.Font.textFieldStatus
        statusLabel.textColor = DataEntry.Color.textFieldStatus
        
        textView.textColor = DataEntry.Color.text
        textView.font = DataEntry.Font.text
        textView.layer.borderColor = DataEntry.Color.border.cgColor
        textView.layer.borderWidth = DataEntry.Metric.borderThickness
        textView.layer.cornerRadius = DataEntry.Metric.cornerRadius
        
        cornerRadius = DataEntry.Metric.cornerRadius
        layer.borderWidth = DataEntry.Metric.borderThickness
        backgroundColor = DataEntry.Color.textFieldBackground
        textView.backgroundColor = .clear
        layer.borderColor = errorState.textFieldBorderColor(whileEditing: isFirstResponder).cgColor
        errorState = .none
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
        return textView.becomeFirstResponder()
    }

    private func makeToolbarWithDoneButton() -> UIToolbar {
        //Frame needed, but actual values aren't that important
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        toolbar.barStyle = .default

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: R.string.localizable.done(), style: .done, target: self, action: #selector(doneButtonTapped))

        toolbar.items = [flexSpace, done]
        toolbar.sizeToFit()

        return toolbar
    }

    private func makeToolbarWithNextButton() -> UIToolbar {
        //Frame needed, but actual values aren't that important
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        toolbar.barStyle = .default

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let next = UIBarButtonItem(title: R.string.localizable.next(), style: .plain, target: self, action: #selector(nextButtonTapped))
        toolbar.items = [flexSpace, next]
        toolbar.sizeToFit()

        return toolbar
    }

    @objc func doneButtonTapped() {
        delegate?.doneButtonTapped(for: self)
    }

    @objc func nextButtonTapped() {
        delegate?.nextButtonTapped(for: self)
    }
}

extension TextView: UITextViewDelegate {

    func textViewDidBeginEditing(_ textView: UITextView) {
        let borderColor = errorState.textFieldBorderColor(whileEditing: true)
        layer.borderColor = borderColor.cgColor
        backgroundColor = Colors.appWhite

        dropShadow(color: borderColor, radius: DataEntry.Metric.shadowRadius)
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        let borderColor = errorState.textFieldBorderColor(whileEditing: false)
        let shouldDropShadow = errorState.textFieldShowShadow(whileEditing: false)
        layer.borderColor = borderColor.cgColor
        backgroundColor = DataEntry.Color.textFieldBackground

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
