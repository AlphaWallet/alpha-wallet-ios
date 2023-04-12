//
//  EditLegacyGasPriceView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.04.2023.
//

import Combine
import UIKit

protocol EditGasPriceViewDelegate: AnyObject {
    func doneButtonTapped(for textField: UIView)
    func nextButtonTapped(for textField: UIView)
}

class EditLegacyGasPriceView: UIView {
    private let viewModel: EditLegacyGasPriceViewModel
    private lazy var textField: SlidableTextField = {
        let editGasPriceView = SlidableTextField(viewModel: viewModel.sliderViewModel)
        editGasPriceView.delegate = self
        editGasPriceView.textField.inputAccessoryButtonType = .next
        editGasPriceView.keyboardType = .decimalPad
        
        return editGasPriceView
    }()
    private let headerView = GasSpeedTableViewHeaderView()
    private var cancellable = Set<AnyCancellable>()

    weak var delegate: EditGasPriceViewDelegate?

    init(viewModel: EditLegacyGasPriceViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        let stackView = [
            headerView,
            textField
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        NSLayoutConstraint.activate([stackView.anchorsConstraint(to: self)])
        bind(viewModel: viewModel)
    }

    private func bind(viewModel: EditLegacyGasPriceViewModel) {
        let input = EditLegacyGasPriceViewModelInput()
        let output = viewModel.trasform(input: input)

        output.title
            .sink { [weak headerView] in headerView?.configure(viewModel: .init(title: $0)) }
            .store(in: &cancellable)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension EditLegacyGasPriceView: SlidableTextFieldDelegate {

    func shouldReturn(in textField: SlidableTextField) -> Bool {
        return true
    }

    func doneButtonTapped(for textField: SlidableTextField) {
        delegate?.doneButtonTapped(for: self)
    }

    func nextButtonTapped(for textField: SlidableTextField) {
        delegate?.nextButtonTapped(for: self)
    }
}
