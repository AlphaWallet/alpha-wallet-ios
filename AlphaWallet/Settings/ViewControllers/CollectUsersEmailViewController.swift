//
//  CollectUsersEmailViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.09.2021.
//

import UIKit

protocol CollectUsersEmailViewControllerDelegate: class {
    func didClose(in viewController: CollectUsersEmailViewController)
    func didFinish(in viewController: CollectUsersEmailViewController, email: String)
}

struct CollectUsersEmailViewModel {
    let title: String = R.string.localizable.emailListPromptTitle()
    let description: String = R.string.localizable.emailListPromptMessage()
    let receiveEmailButtonTitle: String = R.string.localizable.emailListPromptSubscribeButtonTitle()
    let emailTextFieldPlaceholder: String = R.string.localizable.emailListPromptEmailPlaceholder()
}

class CollectUsersEmailViewController: ModalViewController {
    weak var _delegate: CollectUsersEmailViewControllerDelegate?

    private var titleLabel: UILabel = {
        let v = UILabel()
        v.numberOfLines = 0
        v.textAlignment = .center
        v.textColor = Configuration.Color.Semantic.defaultForegroundText
        v.font = Fonts.bold(size: 24)

        return v
    }()

    private var descriptionLabel: UILabel = {
        let v = UILabel()
        v.numberOfLines = 0
        v.textAlignment = .center
        v.textColor = Configuration.Color.Semantic.defaultSubtitleText
        v.font = Fonts.regular(size: 17)

        return v
    }()

    private lazy var textField: TextField = {
        let textField: TextField = .textField
        textField.keyboardType = .emailAddress
        textField.returnKeyType = .done
        textField.delegate = self

        return textField
    }()

    private lazy var buttonsBar: HorizontalButtonsBar = {
        let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
        buttonsBar.backgroundColor = Configuration.Color.Semantic.dialogBackground
        return buttonsBar
    }()

    init() {
        super.init(nibName: nil, bundle: nil)
        let footerView = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0)
        footerView.backgroundColor = Configuration.Color.Semantic.dialogBackground
        footerStackView.addArrangedSubview(footerView)
        generateSubviews()
        presentationDelegate = self

        textField.status = .none
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: CollectUsersEmailViewModel) {
        buttonsBar.configure()
        buttonsBar.buttons[0].setTitle(viewModel.receiveEmailButtonTitle, for: .normal)
        buttonsBar.buttons[0].addTarget(self, action: #selector(receiveEmailSelected), for: .touchUpInside)

        titleLabel.text = viewModel.title
        descriptionLabel.text = viewModel.description
        textField.placeholder = viewModel.emailTextFieldPlaceholder
    }

    @objc private func receiveEmailSelected(_ sender: UIButton) {
        let email = textField.value
        guard email.isValidAsEmail || email.isEmpty else {
            textField.status = .error(R.string.localizable.emailListEmailInvalid())
            return
        }

        textField.status = .none
        view.endEditing(true)

        dismissViewAnimated(with: {
            self._delegate?.didFinish(in: self, email: email)
            self.dismiss(animated: false)
        })
    }
}

extension CollectUsersEmailViewController: TextFieldDelegate {

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

extension CollectUsersEmailViewController: ModalViewControllerDelegate {

    func didDismiss(_ controller: ModalViewController) {
        view.endEditing(true)
        _delegate?.didClose(in: self)
        dismiss(animated: false)
    }

    func didClose(_ controller: ModalViewController) {
        view.endEditing(true)

        dismissViewAnimated(with: {
            self._delegate?.didClose(in: self)
            self.dismiss(animated: false)
        })
    }
}

extension CollectUsersEmailViewController {
    private func generateSubviews() {
        stackView.removeAllArrangedSubviews()

        let views: [UIView] = [
            [.spacerWidth(16), titleLabel, .spacerWidth(16)].asStackView(axis: .horizontal),
            .spacer(height: 20),
            [.spacerWidth(16), descriptionLabel, .spacerWidth(16)].asStackView(axis: .horizontal),
            .spacer(height: 20),
            [.spacerWidth(16), textField, .spacerWidth(16)].asStackView(axis: .horizontal)
        ]

        stackView.addArrangedSubviews(views)
    }
}

