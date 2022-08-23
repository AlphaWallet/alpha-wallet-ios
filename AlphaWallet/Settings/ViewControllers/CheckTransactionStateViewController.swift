//
//  File.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.03.2022.
//

import Foundation
import PromiseKit
import web3swift

protocol SelectTransactionHashViewControllerDelegate: class {
    func didClose(in viewController: CheckTransactionStateViewController)
    func didSelectServerSelected(in viewController: CheckTransactionStateViewController)
    func didSelectedCheckTransactionStatus(in viewController: CheckTransactionStateViewController, transactionHash: String)
}

class CheckTransactionStateViewController: ModalViewController {
    weak var _delegate: SelectTransactionHashViewControllerDelegate?

    private var titleLabel: UILabel = {
        let v = UILabel()
        v.numberOfLines = 0
        v.textAlignment = .center
        v.textColor = R.color.black()
        v.font = Fonts.bold(size: 24)

        return v
    }()

    private lazy var textField: TextField = {
        let textField: TextField = .textField
        textField.keyboardType = .emailAddress
        textField.returnKeyType = .done
        textField.delegate = self

        return textField
    }()

    private lazy var serverView: TransactionConfirmationHeaderView = {
        let view = TransactionConfirmationHeaderView(viewModel: viewModel.serverSelectionViewModel)
        view.delegate = self
        view.enableTapAction(title: R.string.localizable.editButtonTitle())

        return view
    }()

    private lazy var buttonsBar: HorizontalButtonsBar = {
        let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
        return buttonsBar
    }()

    private var viewModel: CheckTransactionStateViewModel

    init(viewModel: CheckTransactionStateViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        let footerView = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0)

        footerStackView.addArrangedSubview(footerView)
        generateSubviews()
        presentationDelegate = self

        textField.status = .none

        buttonsBar.configure()
        buttonsBar.buttons[0].setTitle(viewModel.actionButtonTitle, for: .normal)
        buttonsBar.buttons[0].addTarget(self, action: #selector(checkTransactionStatusSelected), for: .touchUpInside)

        titleLabel.text = viewModel.title
    }

    func set(isActionButtonEnable isEnabled: Bool) {
        buttonsBar.buttons[0].isEnabled = isEnabled
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: CheckTransactionStateViewModel) {
        self.viewModel = viewModel
        textField.placeholder = viewModel.textFieldPlaceholder
        serverView.configure(viewModel: viewModel.serverSelectionViewModel)
    }

    func dismissAnimated(completion: @escaping () -> Void) {
        dismissViewAnimated(with: {
            self._delegate?.didClose(in: self)
            self.dismiss(animated: false)
            completion()
        })
    }

    @objc private func checkTransactionStatusSelected(_ sender: UIButton) {
        let transactionHash = textField.value
        guard !transactionHash.isEmpty else {
            textField.status = .error("Transaction hash is invalid")
            return
        }

        textField.status = .none
        view.endEditing(true)
        self._delegate?.didSelectedCheckTransactionStatus(in: self, transactionHash: transactionHash)
    }
}

extension CheckTransactionStateViewController: TransactionConfirmationHeaderViewDelegate {
    func headerView(_ header: TransactionConfirmationHeaderView, shouldHideChildren section: Int, index: Int) -> Bool {
        return false
    }

    func headerView(_ header: TransactionConfirmationHeaderView, shouldShowChildren section: Int, index: Int) -> Bool {
        return false
    }

    func headerView(_ header: TransactionConfirmationHeaderView, openStateChanged section: Int) {
        //no-op
    }

    func headerView(_ header: TransactionConfirmationHeaderView, tappedSection section: Int) {
        _delegate?.didSelectServerSelected(in: self)
    }
}

extension CheckTransactionStateViewController: TextFieldDelegate {

    func shouldReturn(in textField: TextField) -> Bool {
        view.endEditing(true)
        return false
    }

    func doneButtonTapped(for textField: TextField) {
        view.endEditing(true)
    }

    func nextButtonTapped(for textField: TextField) {
        view.endEditing(true)
    }
}

extension CheckTransactionStateViewController: ModalViewControllerDelegate {

    func didDismiss(_ controller: ModalViewController) {
        _delegate?.didClose(in: self)
        dismiss(animated: false)
    }

    func didClose(_ controller: ModalViewController) {
        dismissViewAnimated(with: {
            self._delegate?.didClose(in: self)
            self.dismiss(animated: false)
        })
    }
}

extension CheckTransactionStateViewController {
    private func generateSubviews() {
        stackView.removeAllArrangedSubviews()

        let views: [UIView] = [
            [.spacerWidth(16), titleLabel, .spacerWidth(16)].asStackView(axis: .horizontal),
            .spacer(height: 20),
            serverView,
            .spacer(height: 20),
            [.spacerWidth(16), textField, .spacerWidth(16)].asStackView(axis: .horizontal),
        ]

        stackView.addArrangedSubviews(views)
    }
}
