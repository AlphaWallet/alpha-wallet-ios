//
//  SlidableTextField.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.08.2020.
//

import UIKit
import AlphaWalletFoundation

protocol SlidableTextFieldDelegate: AnyObject {
    func textField(_ textField: SlidableTextField, textDidChange value: Int)
    func textField(_ textField: SlidableTextField, valueDidChange value: Int)
    func shouldReturn(in textField: TextField) -> Bool
    func doneButtonTapped(for textField: TextField)
    func nextButtonTapped(for textField: TextField)
}

class SlidableTextField: UIView {

    static let contentInsets: UIEdgeInsets = {
        let topBottomInset: CGFloat = ScreenChecker().isNarrowScreen ? 10 : 20
        let sideInset: CGFloat = ScreenChecker().isNarrowScreen ? 8 : 16

        return .init(top: sideInset, left: topBottomInset, bottom: sideInset, right: topBottomInset)
    }()

    private lazy var slider: UISlider = {
        let slider = UISlider(frame: .zero)
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.isUserInteractionEnabled = true

        return slider
    }()

    lazy var textField: TextField = {
        let textField: TextField = .textField
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.keyboardType = .numberPad
        textField.delegate = self

        return textField
    }()

    var value: Int {
        return Int(slider.value)
    }
    weak var delegate: SlidableTextFieldDelegate?

    init() {
        super.init(frame: .zero)

        let spacing: CGFloat = ScreenChecker().isNarrowScreen ? 8 : 16
        let row0 = [slider, textField].asStackView(axis: .horizontal, spacing: spacing)
        let row1 = textField.statusLabel
        let stackView = [
            row0,
            row1
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            textField.widthAnchor.constraint(equalToConstant: 100),
            stackView.anchorsConstraint(to: self, edgeInsets: SlidableTextField.contentInsets)
        ])

        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configureSliderRange(viewModel: SlidableTextFieldViewModel) {
        slider.minimumValue = Float(viewModel.minimumValue)
        slider.maximumValue = Float(viewModel.maximumValue)
        slider.setValue(Float(viewModel.value), animated: false)
    }

    func configure(viewModel: SlidableTextFieldViewModel) {
        configureSliderRange(viewModel: viewModel)

        textField.value = String(viewModel.value)
    }

    @objc private func sliderValueChanged(_ sender: UISlider) {
        textField.value = String(Int(sender.value))
        notifyValueDidChange(value: value)
    }

    private func notifyValueDidChange(value: Int) {
        delegate?.textField(self, valueDidChange: value)
    }
}

extension SlidableTextField: TextFieldDelegate {

    func shouldReturn(in textField: TextField) -> Bool {
        return delegate?.shouldReturn(in: textField) ?? true
    }

    func doneButtonTapped(for textField: TextField) {
        delegate?.doneButtonTapped(for: textField)
    }

    func nextButtonTapped(for textField: TextField) {
        delegate?.nextButtonTapped(for: textField)
    }

    func shouldChangeCharacters(inRange range: NSRange, replacementString string: String, for textField: TextField) -> Bool {
        guard string.isNumeric() || string.isEmpty else { return false }
        let convertedNSString = textField.value as NSString
        let newString: String = convertedNSString.replacingCharacters(in: range, with: string)
        if newString.isEmpty {
            return true
        } else {
            guard let value = Int(newString), let delegate = delegate else { return false }
            slider.setValue(Float(value), animated: false)
            delegate.textField(self, textDidChange: value)
            return true
        }
    }
}

