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
    let title: String = R.string.localizable.emailListPromptTitle(preferredLanguages: Languages.preferred())
    let description: String = R.string.localizable.emailListPromptMessage(preferredLanguages: Languages.preferred())
    let receiveEmailButtonTitle: String = R.string.localizable.emailListPromptSubscribeButtonTitle(preferredLanguages: Languages.preferred())
    let emailTextFieldPlaceholder: String = R.string.localizable.emailListPromptEmailPlaceholder(preferredLanguages: Languages.preferred())
}

class CollectUsersEmailViewController: ModalViewController {
    weak var _delegate: CollectUsersEmailViewControllerDelegate?

    private var titleLabel: UILabel = {
        let v = UILabel()
        v.numberOfLines = 0
        v.textAlignment = .center
        v.textColor = R.color.black()
        v.font = Fonts.bold(size: 24)

        return v
    }()

    private var descriptionLabel: UILabel = {
        let v = UILabel()
        v.numberOfLines = 0
        v.textAlignment = .center
        v.textColor = R.color.mine()
        v.font = Fonts.regular(size: 17)

        return v
    }()

    private lazy var textField: TextField = {
        let tx = TextField()
        tx.configureOnce()
        tx.keyboardType = .emailAddress
        tx.returnKeyType = .done
        tx.delegate = self

        return tx
    }()

    private lazy var buttonsBar: ButtonsBar = {
        let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))
        return buttonsBar
    }()

    init() {
        super.init(nibName: nil, bundle: nil)
        let footerView = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0)

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
            textField.status = .error("Email is not valid")
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

extension String {
    var isValidAsEmail: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"

        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return predicate.evaluate(with: self)
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

