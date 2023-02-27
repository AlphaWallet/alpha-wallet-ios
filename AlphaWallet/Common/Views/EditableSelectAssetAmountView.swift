//
//  EditableSelectAssetAmountView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.02.2023.
//

import UIKit
import Combine

private class SelectAssetHeaderView: UIView {

    let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()

    var closeButton: Button = {
        let button = Button(size: .normal, style: .borderless)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(R.image.close(), for: .normal)
        button.heightConstraint.flatMap { NSLayoutConstraint.deactivate([$0]) }

        return button
    }()

    init() {
        super.init(frame: .zero)

        addSubview(titleLabel)
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        return nil
    }
}

class EditableSelectAssetAmountView: UIView {

    private var headerView: SelectAssetHeaderView = {
        let view = SelectAssetHeaderView()
        return view
    }()

    private lazy var selectionView: SelectAssetAmountView = {
        return SelectAssetAmountView(viewModel: viewModel.selectionViewModel)
    }()

    private var separatorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false

        return view
    }()
    private let text = PassthroughSubject<String, Never>()
    private let close = PassthroughSubject<Void, Never>()
    private var cancellable = Set<AnyCancellable>()

    let viewModel: EditableSelectAssetAmountViewModel

    init(viewModel: EditableSelectAssetAmountViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)

        let stackView = [headerView, separatorView, selectionView].asStackView(axis: .vertical, spacing: 1)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: self),

            headerView.heightAnchor.constraint(equalToConstant: 60),
        ])

        backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        bind(viewModel: viewModel)
    }

    private func bind(viewModel: EditableSelectAssetAmountViewModel) {
        let close = Publishers.Merge(
            self.close,
            headerView.closeButton.publisher(forEvent: .touchUpInside)).eraseToAnyPublisher()

        let input = EditableSelectAssetAmountViewModelInput(
            text: text.eraseToAnyPublisher(),
            close: close)
        let output = viewModel.transform(input: input)

        output.title
            .assign(to: \.attributedText, on: headerView.titleLabel)
            .store(in: &cancellable)
    }

    required init?(coder: NSCoder) {
        return nil
    }
}

extension EditableSelectAssetAmountView: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let newValue = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
        text.send(newValue)

        return true
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        close.send(())
        return true
    }
}

