// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import Eureka

protocol EnterPasswordViewControllerDelegate: class {
    func didEnterPassword(password: String, for account: AlphaWallet.Address, inViewController viewController: EnterPasswordViewController)
}

class EnterPasswordViewController: FormViewController {
    struct ValidationError: LocalizedError {
        var msg: String
        var errorDescription: String? {
            return msg
        }
    }

    struct Values {
        static var password = "password"
    }

    private let viewModel = EnterPasswordViewModel()
    private let account: AlphaWallet.Address
    private var passwordTextField: UITextField?

    private var passwordRow: TextFloatLabelRow? {
        return form.rowBy(tag: Values.password) as? TextFloatLabelRow
    }

    weak var delegate: EnterPasswordViewControllerDelegate?

    init(account: AlphaWallet.Address) {
        self.account = account
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = viewModel.title
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: R.string.localizable.done(), style: .done, target: self, action: #selector(done))

        let ruleMin = RuleMinLength(minLength: 6)

        form = Section()

            +++ Section(header: "", footer: viewModel.headerSectionText)

            <<< AppFormAppearance.textFieldFloat(tag: Values.password) {
                $0.add(rule: RuleRequired())
                $0.add(rule: ruleMin)
                $0.validationOptions = .validatesOnDemand
            }.cellUpdate { cell, _ in
                cell.textField.isSecureTextEntry = false
                cell.textField.placeholder = self.viewModel.passwordFieldPlaceholder
                cell.textField.rightView = {
                    let button = UIButton(type: .system)
                    button.frame = .init(x: 0, y: 0, width: 30, height: 30)
                    button.setImage(R.image.togglePassword(), for: .normal)
                    button.tintColor = .init(red: 111, green: 111, blue: 111)
                    button.addTarget(self, action: #selector(self.toggleMaskPassword), for: .touchUpInside)
                    return button
                }()
                cell.textField.rightViewMode = .unlessEditing
                cell.textField.autocorrectionType = .no
                self.passwordTextField = cell.textField
            }

            +++ Section()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        passwordRow?.cell.textField.becomeFirstResponder()
    }

    @objc func done() {
        guard form.validate().isEmpty, let password = passwordRow?.value else { return }
        delegate?.didEnterPassword(password: password, for: account, inViewController: self)
    }

    @objc private func toggleMaskPassword() {
        guard let passwordTextField = passwordTextField else { return }
        passwordTextField.isSecureTextEntry = !passwordTextField.isSecureTextEntry
        guard let button = passwordTextField.rightView as? UIButton else { return }
        if passwordTextField.isSecureTextEntry {
            button.tintColor = Colors.navigationTitleColor
        } else {
            button.tintColor = .init(red: 111, green: 111, blue: 111)
        }
    }
}
