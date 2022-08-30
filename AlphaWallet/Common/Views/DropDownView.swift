//
//  DropDownView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.08.2021.
//

import UIKit

protocol DropDownViewDelegate: class {
    func filterDropDownViewDidChange(selection: ControlSelection)
}

final class DropDownView<T: DropDownItemType>: UIView, ReusableTableHeaderViewType, UIPickerViewDelegate, UIPickerViewDataSource {

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return viewModel.selectionItems.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return viewModel.selectionItems[row].title
    }

    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        return viewModel.attributedString(item: viewModel.selectionItems[row])
    }

    private var selected: ControlSelection
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selected = .selected(UInt(row))
    }

    private var viewModel: DropDownViewModel<T>
    weak var delegate: DropDownViewDelegate?

    private lazy var hiddenTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.inputAccessoryView = UIToolbar.doneToolbarButton(#selector(doneSelected), self)
        textField.inputView = pickerView
        textField.isHidden = true

        return textField
    }()

    private lazy var pickerView: UIPickerView = {
        let pickerView = UIPickerView(frame: CGRect(x: 0, y: 0, width: bounds.size.width, height: 200))
        pickerView.translatesAutoresizingMaskIntoConstraints = false
        pickerView.delegate = self
        pickerView.dataSource = self

        return pickerView
    }()

    private lazy var selectionButton: Button = {
        let button = Button(size: .normal, style: .special)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(selectionButtonSelected), for: .touchUpInside)
        button.setImage(R.image.iconsSystemExpandMore(), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.semanticContentAttribute = .forceRightToLeft
        button.heightConstraint.flatMap { NSLayoutConstraint.deactivate([$0]) }
        
        return button
    }()

    init(viewModel: DropDownViewModel<T>) {
        self.viewModel = viewModel
        self.selected = viewModel.selected
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        addSubview(hiddenTextField)
        addSubview(selectionButton)

        NSLayoutConstraint.activate([
            selectionButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            selectionButton.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            selectionButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
        ])

        configure(viewModel: viewModel)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: DropDownViewModel<T>) {
        self.viewModel = viewModel
        self.selected = viewModel.selected
        configure(selection: viewModel.selected)
    }

    @objc private func selectionButtonSelected(_ sender: UIButton) {
        hiddenTextField.becomeFirstResponder()
    }

    @objc private func doneSelected(_ sender: UITextField) {
        hiddenTextField.endEditing(true)

        viewModel.selected = selected
        configure(selection: viewModel.selected)

        delegate?.filterDropDownViewDidChange(selection: viewModel.selected)
    }

    private func configure(selection: ControlSelection) {
        let placeholder = viewModel.placeholder(for: selection)
        selectionButton.setTitle(placeholder, for: .normal)
        selectionButton.semanticContentAttribute = .forceRightToLeft
    }

    func value(from selection: ControlSelection) -> T? {
        switch selection {
        case .unselected:
            return nil
        case .selected(let index):
            guard viewModel.selectionItems.indices.contains(Int(index)) else { return nil }
            return viewModel.selectionItems[Int(index)]
        }
    }
}

