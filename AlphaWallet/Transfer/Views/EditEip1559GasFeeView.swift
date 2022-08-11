//
//  EditEip1559GasFeeView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.04.2023.
//

import Combine
import UIKit

class EditEip1559GasFeeView: UIView {
    private let viewModel: EditEip1559GasFeeViewModel
    private let maxFeeHeaderView = GasSpeedTableViewHeaderView()
    private lazy var maxFeeTextField: SlidableTextField = {
        let slider = SlidableTextField(viewModel: viewModel.maxFeeSliderViewModel)
        slider.delegate = self
        slider.textField.inputAccessoryButtonType = .next

        return slider
    }()
    private let maxPriorityFeeHeaderView = GasSpeedTableViewHeaderView()
    private lazy var maxPriorityFeeTextField: SlidableTextField = {
        let slider = SlidableTextField(viewModel: viewModel.maxPriorityFeeSliderViewModel)
        slider.delegate = self
        slider.textField.inputAccessoryButtonType = .next

        return slider
    }()
    private var cancellable = Set<AnyCancellable>()

    weak var delegate: EditGasPriceViewDelegate?

    init(viewModel: EditEip1559GasFeeViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        let stackView = [
            maxFeeHeaderView,
            maxFeeTextField,
            UIView.separator(),
            maxPriorityFeeHeaderView,
            maxPriorityFeeTextField
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        NSLayoutConstraint.activate([stackView.anchorsConstraint(to: self)])

        bind(viewModel: viewModel)
    }

    private func bind(viewModel: EditEip1559GasFeeViewModel) {
        let input = EditEip1559GasFeeViewModelInput()
        let output = viewModel.trasform(input: input)

        output.maxFeeHeader
            .sink { [weak self] in self?.maxFeeHeaderView.configure(viewModel: .init(title: $0)) }
            .store(in: &cancellable)

        output.maxPriorityFeeHeader
            .sink { [weak self] in self?.maxPriorityFeeHeaderView.configure(viewModel: .init(title: $0)) }
            .store(in: &cancellable)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension EditEip1559GasFeeView: SlidableTextFieldDelegate {

    func shouldReturn(in textField: SlidableTextField) -> Bool {
        return true
    }

    func doneButtonTapped(for textField: SlidableTextField) {
        delegate?.doneButtonTapped(for: self)
    }

    func nextButtonTapped(for textField: SlidableTextField) {
        if textField == maxFeeTextField {
            maxPriorityFeeTextField.becomeFirstResponder()
        } else if textField == maxPriorityFeeTextField {
            delegate?.nextButtonTapped(for: self)
        } else {
            delegate?.nextButtonTapped(for: self)
        }
    }
}

