//
//  SelectableTokenCardContainerTableViewCell.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit

protocol SelectableTokenCardContainerTableViewCellDelegate: class {
    func didCloseSelection(in sender: SelectableTokenCardContainerTableViewCell, with selectedAmount: Int)
}

class SelectableTokenCardContainerTableViewCell: ContainerTableViewCell {
    private var viewModel: SelectableTokenCardContainerTableViewCellViewModel?

    private var selectionStateViews: (containerView: UIView, selectionImageView: UIImageView) = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false

        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(imageView)

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 40),
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 25),
            imageView.heightAnchor.constraint(equalToConstant: 25),
        ])

        return (view, imageView)
    }()

    weak var delegate: SelectableTokenCardContainerTableViewCellDelegate?

    private lazy var hiddenTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.inputAccessoryView = toolbar
        textField.isHidden = true
        textField.keyboardType = .numberPad
        textField.delegate = toolbarAmountSelectionView

        return textField
    }()

    private lazy var toolbarAmountSelectionView: SingleTokenCardAmountSelectionToolbarView = {
        let view = SingleTokenCardAmountSelectionToolbarView(viewModel: .init())
        view.delegate = self

        return view
    }()

    private lazy var toolbar: UIToolbar = {
        let toolbar = UIToolbar.customToolbar(with: toolbarAmountSelectionView, height: 130)
        toolbar.isTranslucent = false
        toolbar.barTintColor = toolbarAmountSelectionView.backgroundColor

        return toolbar
    }()

    private let selectedAmountView: SingleTokenCardSelectionView = {
        let view = SingleTokenCardSelectionView()
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        stackView.removeAllArrangedSubviews()
        stackView.addArrangedSubviews([selectionStateViews.containerView, viewContainerView])

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTap)))
        isUserInteractionEnabled = true
        addSubview(hiddenTextField)
    }

    private var selectionViewPositioningConstraints: [NSLayoutConstraint] = []

    func prapare(with view: UIView & SelectionPositioningView) {
        super.configure(subview: view)

        NSLayoutConstraint.deactivate(selectionViewPositioningConstraints)
        selectedAmountView.removeFromSuperview()

        view.positioningView.addSubview(selectedAmountView)

        selectionViewPositioningConstraints = [
            selectedAmountView.centerXAnchor.constraint(equalTo: view.positioningView.centerXAnchor),
            selectedAmountView.centerYAnchor.constraint(equalTo: view.positioningView.centerYAnchor),

            selectedAmountView.heightAnchor.constraint(equalToConstant: 35),
            selectedAmountView.widthAnchor.constraint(equalToConstant: 35)
        ]

        NSLayoutConstraint.activate(selectionViewPositioningConstraints)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: SelectableTokenCardContainerTableViewCellViewModel) {
        self.viewModel = viewModel

        backgroundColor = viewModel.contentsBackgroundColor
        background.backgroundColor = viewModel.contentsBackgroundColor
        contentView.backgroundColor = viewModel.contentsBackgroundColor

        selectedAmountView.configure(viewModel: viewModel.selectionViewModel)
        toolbarAmountSelectionView.configure(viewModel: viewModel.cardAmountSelectionToolbarViewModel)

        selectionStateViews.selectionImageView.image = viewModel.selectionImage
    }

    @objc private func didTap(_ sender: UITapGestureRecognizer) {
        if let viewModel = viewModel, viewModel.selectionViewModel.isSingleSelectionEnabled {
            let newSelection = viewModel.selectionViewModel.isSelected ? 0 : 1

            delegate?.didCloseSelection(in: self, with: newSelection)
        } else {
            hiddenTextField.becomeFirstResponder()
        }
    }

    @objc private func doneSelected(_ sender: UITextField) {
        hiddenTextField.endEditing(true)
    }
}

extension SelectableTokenCardContainerTableViewCell: SingleTokenCardAmountSelectionToolbarViewDelegate {
    func closeSelected(in view: SingleTokenCardAmountSelectionToolbarView) {
        delegate?.didCloseSelection(in: self, with: view.viewModel.counter)
    }
}
