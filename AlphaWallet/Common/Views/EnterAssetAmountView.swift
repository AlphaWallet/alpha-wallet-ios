//
//  EnterAssetAmountView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.02.2023.
//

import UIKit
import Combine

class EnterAssetAmountView: UIView {

    private lazy var hiddenTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.inputAccessoryView = toolbar
        textField.isHidden = true
        textField.keyboardType = .numberPad
        textField.delegate = toolbarAmountSelectionView

        return textField
    }()

    private lazy var toolbarAmountSelectionView: EditableSelectAssetAmountView = {
        let view = EditableSelectAssetAmountView(viewModel: viewModel.selectAssetViewModel)
        return view
    }()

    private lazy var toolbar: UIToolbar = {
        let toolbar = UIToolbar.customToolbar(with: toolbarAmountSelectionView, height: 130)
        toolbar.isTranslucent = false
        toolbar.barTintColor = toolbarAmountSelectionView.backgroundColor

        return toolbar
    }()
    private let viewModel: EnterAssetAmountViewModel

    var cancellable = Set<AnyCancellable>()

    init(viewModel: EnterAssetAmountViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)

        addSubview(hiddenTextField)
        bind(viewModel: viewModel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func bind(viewModel: EnterAssetAmountViewModel) {
        let output = viewModel.transform(input: .init())

        output.activate
            .sink { [hiddenTextField] _ in hiddenTextField.becomeFirstResponder() }
            .store(in: &cancellable)

        output.close
            .sink { [hiddenTextField] _ in hiddenTextField.resignFirstResponder() }
            .store(in: &cancellable)
    }

}
