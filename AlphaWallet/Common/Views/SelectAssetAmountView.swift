//
//  TokenCardSelectionAmountView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 31.08.2021.
//

import UIKit

struct SelectTokenCardAmountViewModel {
    var backgroundColor: UIColor = Colors.appWhite
    private let availableAmount: Int
    private(set) var counter: Int = 0

    init(availableAmount: Int, selectedAmount: Int) {
        self.availableAmount = availableAmount
        self.counter = selectedAmount
    }

    var amountTextFont: UIFont = Fonts.bold(size: 24)
    var amountTextColor: UIColor = Colors.black

    mutating func increaseCounter() {
        guard counter + 1 <= availableAmount else { return }
        counter += 1
    }

    mutating func decreaseCounter() {
        guard counter - 1 >= 0 else { return }
        counter -= 1
    }

    mutating func set(counter: Int) {
        self.counter = counter
    }

    mutating func set(counter: String) {
        if counter.isEmpty {
            self.counter = 0
        } else {
            guard let value = Int(counter), value >= 0 && value <= availableAmount else { return }
            self.counter = value
        }
    }
}

private class TokenCardSelectionAmountHeaderView: UIView {

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

protocol SelectTokenCardAmountViewDelegate: class {
    func valueDidChange(in view: SelectTokenCardAmountView)
}

class SelectTokenCardAmountView: UIView {

    private (set) var plusButton: Button = {
        let button = Button(size: .normal, style: .borderless)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(R.image.iconsSystemAddBorderCircle(), for: .normal)
        button.heightConstraint.flatMap { NSLayoutConstraint.deactivate([$0]) }

        return button
    }()

    private (set) var minusButton: Button = {
        let button = Button(size: .normal, style: .borderless)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(R.image.iconsSystemCircleMinue(), for: .normal)
        button.heightConstraint.flatMap { NSLayoutConstraint.deactivate([$0]) }

        return button
    }()

    private (set) var countLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DataEntry.Font.accessory
        label.textAlignment = .center

        return label
    }()

    private (set) var viewModel: SelectTokenCardAmountViewModel
    weak var delegate: SelectTokenCardAmountViewDelegate?

    init(viewModel: SelectTokenCardAmountViewModel, edgeInsets: UIEdgeInsets = .zero) {
        self.viewModel = viewModel
        super.init(frame: .zero)

        let centeredView: UIView = {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false

            let stackView = [minusButton, countLabel, plusButton].asStackView(axis: .horizontal, spacing: 10)
            stackView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(stackView)

            NSLayoutConstraint.activate([
                countLabel.widthAnchor.constraint(equalToConstant: 50),
                stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])

            return view
        }()

        addSubview(centeredView)
        NSLayoutConstraint.activate([
            centeredView.anchorsConstraint(to: self, edgeInsets: edgeInsets),
            centeredView.heightAnchor.constraint(equalToConstant: 70)
        ])

        minusButton.addTarget(self, action: #selector(minusButtonSelected), for: .touchUpInside)
        plusButton.addTarget(self, action: #selector(plusButtonSelected), for: .touchUpInside)

        configure(viewModel: viewModel)
    }

    func configure(viewModel: SelectTokenCardAmountViewModel) {
        self.viewModel = viewModel

        countLabel.textColor = viewModel.amountTextColor
        countLabel.font = viewModel.amountTextFont
        backgroundColor = viewModel.backgroundColor

        updateCounterLabel()
    }

    private func updateCounterLabel() {
        countLabel.text = String(viewModel.counter)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    @objc private func plusButtonSelected(_ sender: UIButton) {
        viewModel.increaseCounter()
        updateCounterLabel()

        delegate?.valueDidChange(in: self)
    }

    @objc private func minusButtonSelected(_ sender: UIButton) {
        viewModel.decreaseCounter()
        updateCounterLabel()

        delegate?.valueDidChange(in: self)
    }
}

protocol SingleTokenCardAmountSelectionToolbarViewDelegate: class {
    func closeSelected(in: SingleTokenCardAmountSelectionToolbarView)
}

struct SingleTokenCardAmountSelectionToolbarViewModel {
    var backgroundColor: UIColor = Colors.appWhite
    let availableAmount: Int

    var counter: Int {
        selectionViewModel.counter
    }

    var selectionViewModel: SelectTokenCardAmountViewModel

    init(availableAmount: Int = 0, selectedAmount: Int = 0) {
        self.availableAmount = availableAmount
        selectionViewModel = .init(availableAmount: availableAmount, selectedAmount: selectedAmount)
    }

    var attributedTitleString: NSAttributedString {
        return .init(string: "Select Amount (max. \(availableAmount))", attributes: [
            .font: Fonts.semibold(size: 17),
            .foregroundColor: Colors.black
        ])
    }
}

class SingleTokenCardAmountSelectionToolbarView: UIView {

    private var headerView: TokenCardSelectionAmountHeaderView = {
        let view = TokenCardSelectionAmountHeaderView()
        return view
    }()

    private lazy var selectionView: SelectTokenCardAmountView = {
        let view = SelectTokenCardAmountView(viewModel: viewModel.selectionViewModel)
        view.delegate = self
        return view
    }()

    private var separatorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false

        return view
    }()

    weak var delegate: SingleTokenCardAmountSelectionToolbarViewDelegate?

    private (set) var viewModel: SingleTokenCardAmountSelectionToolbarViewModel

    init(viewModel: SingleTokenCardAmountSelectionToolbarViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)

        let stackView = [headerView, separatorView, selectionView].asStackView(axis: .vertical, spacing: 1)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: self),

            headerView.heightAnchor.constraint(equalToConstant: 60),
        ])

        headerView.closeButton.addTarget(self, action: #selector(closeButtonSelected), for: .touchUpInside)

        configure(viewModel: viewModel)
    }

    func configure(viewModel: SingleTokenCardAmountSelectionToolbarViewModel) {
        self.viewModel = viewModel

        selectionView.configure(viewModel: viewModel.selectionViewModel)
        headerView.titleLabel.attributedText = viewModel.attributedTitleString
        backgroundColor = viewModel.backgroundColor
    }

    required init?(coder: NSCoder) {
        return nil
    }

    @objc private func closeButtonSelected(_ sender: UIButton) {
        delegate?.closeSelected(in: self)
    }
}

extension SingleTokenCardAmountSelectionToolbarView: SelectTokenCardAmountViewDelegate {
    func valueDidChange(in view: SelectTokenCardAmountView) {
        viewModel.selectionViewModel.set(counter: view.viewModel.counter)
        configure(viewModel: viewModel)
    }
}

extension SingleTokenCardAmountSelectionToolbarView: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let newValue = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
        viewModel.selectionViewModel.set(counter: newValue)
        configure(viewModel: viewModel)

        return true
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        delegate?.closeSelected(in: self)

        return true
    }
}

