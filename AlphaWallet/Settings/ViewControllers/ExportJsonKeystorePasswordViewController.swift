//
//  ExportJsonKeystorePasswordViewController.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 1/12/21.
//

import UIKit

@objc protocol ExportJsonKeystorePasswordDelegate {
    func didRequestExportKeystore(with password: String)
    func didDismissPasswordController()
}

class ExportJsonKeystorePasswordViewController: UIViewController {
    private let buttonTitle: String
    private var viewModel: ExportJsonKeystorePasswordViewModel
    private lazy var keyboardChecker = KeyboardChecker(self, resetHeightDefaultValue: 0, ignoreBottomSafeArea: true)
    private var passwordView: ExportJsonKeystorePasswordView {
        return view as! ExportJsonKeystorePasswordView
    }
    weak var passwordDelegate: ExportJsonKeystorePasswordDelegate?

    init(viewModel: ExportJsonKeystorePasswordViewModel, buttonTitle: String) {
        self.viewModel = viewModel
        self.buttonTitle = buttonTitle
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureController()
        passwordView.disableButton()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        keyboardChecker.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        keyboardChecker.viewWillDisappear()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if !isStillInNavigationStack() {
            passwordDelegate?.didDismissPasswordController()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async {
            self.passwordView.passwordTextField.becomeFirstResponder()
        }
    }

    override func loadView() {
        view = ExportJsonKeystorePasswordView()
    }

    private func configureController() {
        navigationItem.title = R.string.localizable.settingsAdvancedExportJSONKeystorePasswordTitle()
        passwordView.setButton(title: buttonTitle)
        passwordView.addExportButtonTarget(self, action: #selector(requestExportAction(_:)))
        passwordView.passwordTextField.delegate = self
        keyboardChecker.constraint = passwordView.bottomConstraint
    }

    @objc func requestExportAction(_ sender: UIButton?) {
        guard let password = passwordView.passwordTextField.text else { return }
        switch viewModel.validate(password: password) {
        case .success:
            navigationItem.backButtonTitle = ""
            passwordDelegate?.didRequestExportKeystore(with: password)
        case .failure:
            break
        }
    }
}

extension ExportJsonKeystorePasswordViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard var currentPasswordString = textField.text, let stringRange = Range(range, in: currentPasswordString) else { return true }
        let originalPasswordString = currentPasswordString
        currentPasswordString.replaceSubrange(stringRange, with: string)
        let validPassword = !viewModel.containsIllegalCharacters(password: currentPasswordString)
        if validPassword {
            setButtonState(for: currentPasswordString)
            return true
        } else {
            setButtonState(for: originalPasswordString)
            return false
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }

    func setButtonState(for passwordString: String) {
        let state = viewModel.validate(password: passwordString)
        switch state {
        case .success:
            passwordView.enableButton()
        case .failure:
            passwordView.disableButton()
        }
    }
}
