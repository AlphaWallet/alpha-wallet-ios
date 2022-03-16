// Copyright SIX DAY LLC. All rights reserved.

import UIKit

protocol EnterKeystorePasswordViewControllerDelegate: class {
    func didEnterPassword(password: String, in viewController: EnterKeystorePasswordViewController)
}

class EnterKeystorePasswordViewController: UIViewController {
    private var viewModel: EnterKeystorePasswordViewModel
    private lazy var keyboardChecker = KeyboardChecker(self, resetHeightDefaultValue: 0, ignoreBottomSafeArea: true)
    private var passwordView: EnterKeystorePasswordView {
        return view as! EnterKeystorePasswordView
    }
    weak var delegate: EnterKeystorePasswordViewControllerDelegate?

    init(viewModel: EnterKeystorePasswordViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configure(viewModel: viewModel)
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async {
            self.passwordView.passwordTextField.becomeFirstResponder()
        }
    }

    override func loadView() {
        view = EnterKeystorePasswordView()
    }

    private func configure(viewModel: EnterKeystorePasswordViewModel) {
        self.viewModel = viewModel

        navigationItem.title = viewModel.navigationTitle
        passwordView.configure(viewModel: viewModel)
        passwordView.addButtonTarget(self, action: #selector(savePasswordSelected))
        passwordView.passwordTextField.delegate = self
        keyboardChecker.constraints = [passwordView.bottomConstraint]
    }

    @objc func savePasswordSelected(_ sender: UIButton?) {
        let password = passwordView.passwordTextField.value
        switch viewModel.validate(password: password) {
        case .success:
            navigationItem.backButtonTitle = ""
            delegate?.didEnterPassword(password: password, in: self)
        case .failure:
            break
        }
    }
}

extension EnterKeystorePasswordViewController: TextFieldDelegate {
    func shouldChangeCharacters(inRange range: NSRange, replacementString string: String, for textField: TextField) -> Bool {
        var currentPasswordString = textField.value
        guard let stringRange = Range(range, in: currentPasswordString) else { return true }
        let originalPasswordString = currentPasswordString
        currentPasswordString.replaceSubrange(stringRange, with: string)

        let validPassword = !viewModel.containsIllegalCharacters(password: currentPasswordString)
        setButtonState(for: validPassword ? currentPasswordString: originalPasswordString)

        return validPassword
    }

    func shouldReturn(in textField: TextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }

    func doneButtonTapped(for textField: TextField) {
        //no-op
    }

    func nextButtonTapped(for textField: TextField) {
        //no-op
    }

    private func setButtonState(for passwordString: String) {
        switch viewModel.validate(password: passwordString) {
        case .success:
            passwordView.enableButton()
        case .failure:
            passwordView.disableButton()
        }
    }
}

private class EnterKeystorePasswordView: UIView {

    private lazy var label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontForContentSizeCategory = true
        label.backgroundColor = R.color.white()!
        label.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: Fonts.regular(size: 13.0))
        label.textColor = R.color.dove()!
        label.text = R.string.localizable.enterPasswordPasswordHeaderPlaceholder()
        label.numberOfLines = 0
        return label
    }()

    lazy var passwordTextField: PasswordTextField = {
        let textField = PasswordTextField()
        textField.configureOnce()
        textField.placeholder = R.string.localizable.enterPasswordPasswordTextFieldPlaceholder()

        return textField
    }()
    lazy var buttonsBar: HorizontalButtonsBar = {
        let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
        buttonsBar.configure()

        return buttonsBar
    }()
    var bottomConstraint: NSLayoutConstraint!

    init() {
        super.init(frame: .zero)

        backgroundColor = R.color.white()!
        configureTapToDismissKeyboard()

        let edgeInsets = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 16.0, right: 0.0)
        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, edgeInsets: edgeInsets, separatorHeight: 1.0)

        addSubview(label)
        addSubview(passwordTextField)
        addSubview(footerBar)

        bottomConstraint = footerBar.bottomAnchor.constraint(equalTo: self.bottomAnchor)

        NSLayoutConstraint.activate([
            passwordTextField.topAnchor.constraint(equalTo: topAnchor, constant: 34.0),
            passwordTextField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16.0),
            passwordTextField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16.0),

            label.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 20.0),
            label.leadingAnchor.constraint(equalTo: passwordTextField.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: passwordTextField.trailingAnchor),
            label.bottomAnchor.constraint(lessThanOrEqualTo: footerBar.topAnchor, constant: -4.0),

            footerBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomConstraint!
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func addButtonTarget(_ target: Any?, action: Selector) {
        let button = buttonsBar.buttons[0]
        button.removeTarget(target, action: action, for: .touchUpInside)
        button.addTarget(target, action: action, for: .touchUpInside)
    }

    func enableButton() {
        buttonsBar.buttons[0].isEnabled = true
    }

    func disableButton() {
        buttonsBar.buttons[0].isEnabled = false
    }

    func configure(viewModel: EnterKeystorePasswordViewModel) {
        passwordTextField.placeholder = viewModel.passwordFieldPlaceholder
        label.text = viewModel.headerSectionText
        buttonsBar.buttons[0].setTitle(viewModel.buttonTitle, for: .normal)
    }

    private func configureTapToDismissKeyboard() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    @objc private func handleTap(_ sender: Any) {
        endEditing(true)
    }
}
