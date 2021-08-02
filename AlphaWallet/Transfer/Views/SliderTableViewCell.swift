//
//  SliderTableViewCell.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.08.2020.
//

import UIKit

protocol SliderTableViewCellDelegate: AnyObject {
    func cell(_ cell: SliderTableViewCell, textDidChange value: Int)
    func cell(_ cell: SliderTableViewCell, valueDidChange value: Int)
    func shouldReturn(in textField: TextField) -> Bool
    func doneButtonTapped(for textField: TextField)
    func nextButtonTapped(for textField: TextField)
}

class SliderTableViewCell: UITableViewCell {

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
        let textField = TextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.keyboardType = .decimalPad
        textField.delegate = self

        return textField
    }()

    var value: Int {
        return Int(slider.value)
    }
    weak var delegate: SliderTableViewCellDelegate?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        let row0 = [slider, textField].asStackView(axis: .horizontal, spacing: ScreenChecker().isNarrowScreen ? 8 : 16)
        let row1 = textField.statusLabel
        let stackView = [
            row0,
            row1
        ].asStackView(axis: .vertical, spacing: ScreenChecker().isNarrowScreen ? 8 : 16)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            textField.widthAnchor.constraint(equalToConstant: 100),
            stackView.anchorsConstraint(to: contentView, edgeInsets: SliderTableViewCell.contentInsets)
        ])

        textField.configureOnce()
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configureSliderRange(viewModel: SliderTableViewCellViewModel) {
        slider.minimumValue = Float(viewModel.minimumValue)
        slider.maximumValue = Float(viewModel.maximumValue)
        slider.setValue(Float(viewModel.value), animated: false)
    }

    func configure(viewModel: SliderTableViewCellViewModel) {
        configureSliderRange(viewModel: viewModel)

        textField.value = String(viewModel.value)
    }

    @objc private func sliderValueChanged(_ sender: UISlider) {
        textField.value = String(Int(sender.value))
        notifyValueDidChange(value: value)
    }

    private func notifyValueDidChange(value: Int) {
        delegate?.cell(self, valueDidChange: value)
    }
}

extension SliderTableViewCell: TextFieldDelegate {

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
        guard let newString: String = (textField.value as NSString?)?.replacingCharacters(in: range, with: string) else { return false }

        if newString.isEmpty {
            return true
        } else {
            guard let value = Int(newString), let delegate = delegate else { return false }

            slider.setValue(Float(value), animated: false)
            delegate.cell(self, textDidChange: value)

            return true
        }
    }
}

