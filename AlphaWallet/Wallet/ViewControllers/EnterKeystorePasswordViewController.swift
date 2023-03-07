// Copyright SIX DAY LLC. All rights reserved.

import UIKit

protocol EnterKeystorePasswordViewControllerDelegate: AnyObject {
    func didClose(in viewController: EnterKeystorePasswordViewController)
    func didEnterPassword(password: String, in viewController: EnterKeystorePasswordViewController)
}

class EnterKeystorePasswordViewController: UIViewController {
    private var viewModel: EnterKeystorePasswordViewModel
    private lazy var label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontForContentSizeCategory = true
        label.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: Fonts.regular(size: 13.0))
        label.textColor = Configuration.Color.Semantic.defaultSubtitleText
        label.text = R.string.localizable.enterPasswordPasswordHeaderPlaceholder()
        label.numberOfLines = 0

        return label
    }()

    private lazy var passwordTextField: TextField = {
        let textField = TextField.buildPasswordTextField()
        textField.placeholder = R.string.localizable.enterPasswordPasswordTextFieldPlaceholder()
        textField.inputAccessoryButtonType = .done
        textField.delegate = self

        return textField
    }()
    private lazy var buttonsBar: HorizontalButtonsBar = {
        let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
        buttonsBar.configure()

        return buttonsBar
    }()

    private let containerView: ScrollableStackView = {
        let view = ScrollableStackView()
        view.stackView.spacing = 20
        view.stackView.axis = .vertical

        return view
    }()

    weak var delegate: EnterKeystorePasswordViewControllerDelegate?

    init(viewModel: EnterKeystorePasswordViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        let edgeInsets = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 16.0, right: 0.0)
        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, edgeInsets: edgeInsets, separatorHeight: 1.0)

        containerView.stackView.addArrangedSubviews([
            passwordTextField.defaultLayout(),
            label
        ])

        view.addSubview(containerView)
        view.addSubview(footerBar)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 34.0),
            containerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: DataEntry.Metric.Container.xMargin),
            containerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -DataEntry.Metric.Container.xMargin),
            containerView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            footerBar.anchorsConstraint(to: view)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure(viewModel: viewModel)

        buttonsBar.buttons[0].isEnabled = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        DispatchQueue.main.async { [passwordTextField] in
            passwordTextField.becomeFirstResponder()
        }
    }

    private func configure(viewModel: EnterKeystorePasswordViewModel) {
        self.viewModel = viewModel
        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        navigationItem.title = viewModel.title
        passwordTextField.placeholder = viewModel.passwordFieldPlaceholder
        label.text = viewModel.headerSectionText
        buttonsBar.buttons[0].setTitle(viewModel.buttonTitle, for: .normal)
        buttonsBar.buttons[0].addTarget(self, action: #selector(savePasswordSelected), for: .touchUpInside)
    }

    @objc private func savePasswordSelected(_ sender: UIButton?) {
        let password = passwordTextField.value
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
        view.endEditing(true)
    }

    private func setButtonState(for passwordString: String) {
        switch viewModel.validate(password: passwordString) {
        case .success:
            buttonsBar.buttons[0].isEnabled = true
        case .failure:
            buttonsBar.buttons[0].isEnabled = false
        }
    }
}

extension EnterKeystorePasswordViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        delegate?.didClose(in: self)
    }
}
