//
//  EditTransactionViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 04.04.2023.
//

import UIKit
import BigInt
import AlphaWalletFoundation
import Combine

class EditTransactionViewController: UIViewController {
    private lazy var gasLimitHeaderView: GasSpeedTableViewHeaderView = {
        let view: GasSpeedTableViewHeaderView = .init()
        return view
    }()
    private lazy var gasLimitTextField: SlidableTextField = {
        let editGasLimitView = SlidableTextField(viewModel: viewModel.gasLimitSliderViewModel)
        editGasLimitView.delegate = self
        editGasLimitView.textField.inputAccessoryButtonType = .next
        editGasLimitView.keyboardType = .numberPad

        return editGasLimitView
    }()

    private lazy var nonceTextField: TextField = {
        let textField = TextField.buildTextField(viewModel: viewModel.nonceViewModel)
        textField.delegate = self
        textField.keyboardType = .decimalPad

        return textField
    }()

    private lazy var totalFeeTextField: TextField = {
        let textField = TextField.buildTextField(viewModel: viewModel.totalFeeViewModel)
        textField.delegate = self
        textField.inputAccessoryButtonType = .none
        textField.keyboardType = .decimalPad

        return textField
    }()

    private lazy var dataTextField: TextField = {
        let textField = TextField.buildTextField(viewModel: viewModel.dataViewModel)
        textField.delegate = self
        textField.inputAccessoryButtonType = .done
        textField.keyboardType = .decimalPad

        return textField
    }()
    private lazy var editGasView: UIView = {
        if let viewModel = viewModel.gasPriceViewModel as? EditLegacyGasPriceViewModel {
            let view = EditLegacyGasPriceView(viewModel: viewModel)
            view.delegate = self

            return view
        } else if let viewModel = viewModel.gasPriceViewModel as? EditEip1559GasFeeViewModel {
            let view = EditEip1559GasFeeView(viewModel: viewModel)
            view.delegate = self

            return view
        } else {
            fatalError()
        }
    }()
    private lazy var dataTextFieldViews: [UIView] = {
        [dataTextField.defaultLayout(edgeInsets: textFieldInsets), UIView.separator()]
    }()
    private var cancellable = Set<AnyCancellable>()
    private let viewModel: EditTransactionViewModel

    weak var delegate: ConfigureTransactionViewControllerDelegate?

    private lazy var containerView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        return stackView
    }()
    private let textFieldInsets: UIEdgeInsets = {
        let bottomInset: CGFloat = ScreenChecker.size(big: 20, medium: 20, small: 16)

        return .init(top: bottomInset, left: 16, bottom: bottomInset, right: 16)
    }()

    init(viewModel: EditTransactionViewModel) {
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)

        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.anchorsIgnoringBottomSafeArea(to: view)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        generateViews(viewModel: viewModel)
        bind(viewModel: viewModel)
    }

    private func bind(viewModel: EditTransactionViewModel) {
        let input = EditTransactionViewModelInput()
        let output = viewModel.transform(input: input)
        output.gasLimitHeader
            .sink { [weak self] in self?.gasLimitHeaderView.configure(viewModel: .init(title: $0)) }
            .store(in: &cancellable)

        output.isDataFieldHidden
            .sink { [weak self] isHidden in
                self?.dataTextFieldViews.forEach { $0.isHidden = isHidden }
                self?.nonceTextField.inputAccessoryButtonType = isHidden ? .done : .next
            }.store(in: &cancellable)
    }

    private func moveFocusToNextTextField(afterTextField textField: UIView) {
        if textField == gasLimitTextField {
            nonceTextField.becomeFirstResponder()
        } else if textField == nonceTextField {
            dataTextField.becomeFirstResponder()
        }
    }
}

extension EditTransactionViewController: EditGasPriceViewDelegate {

    func nextButtonTapped(for textField: UIView) {
        gasLimitTextField.becomeFirstResponder()
    }

    func doneButtonTapped(for textField: UIView) {
        view.endEditing(true)
    }
}

extension EditTransactionViewController: SlidableTextFieldDelegate {

    func shouldReturn(in textField: SlidableTextField) -> Bool {
        return true
    }

    func doneButtonTapped(for textField: SlidableTextField) {
        view.endEditing(true)
    }

    func nextButtonTapped(for textField: SlidableTextField) {
        moveFocusToNextTextField(afterTextField: textField)
    }
}

extension EditTransactionViewController {

    private func generateViews(viewModel: EditTransactionViewModel) {
        let views: [UIView] = [
            editGasView,
            UIView.separator(),
            gasLimitHeaderView,
            gasLimitTextField,
            UIView.separator(),
            nonceTextField.defaultLayout(edgeInsets: textFieldInsets),
            UIView.separator(),
            totalFeeTextField.defaultLayout(edgeInsets: textFieldInsets),
            UIView.separator(),
        ] + dataTextFieldViews

        containerView.removeAllArrangedSubviews()
        containerView.addArrangedSubviews(views)
    }
}

extension EditTransactionViewController: TextFieldDelegate {

    func shouldReturn(in textField: TextField) -> Bool {
        return true
    }

    func doneButtonTapped(for textField: TextField) {
        view.endEditing(true)
    }

    func nextButtonTapped(for textField: TextField) {
        moveFocusToNextTextField(afterTextField: textField)
    }

    func shouldChangeCharacters(inRange range: NSRange, replacementString string: String, for textField: TextField) -> Bool {
        return true
    }
}
