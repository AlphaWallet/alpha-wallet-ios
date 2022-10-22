//
//  ExportJsonKeystorePasswordViewController.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 1/12/21.
//

import UIKit
import Combine

@objc protocol ExportJsonKeystorePasswordDelegate {
    func exportKeystoreButtonSelected(with password: String, in viewController: ExportJsonKeystorePasswordViewController)
    func didCancel(in viewController: ExportJsonKeystorePasswordViewController)
}

class ExportJsonKeystorePasswordViewController: UIViewController {
    private let viewModel: ExportJsonKeystorePasswordViewModel
    private lazy var passwordTextField: TextField = {
        let textField = TextField.password
        textField.delegate = self
        textField.inputAccessoryButtonType = .done
        textField.label.text = R.string.localizable.settingsAdvancedExportJSONKeystorePasswordLabel()
        textField.placeholder = R.string.localizable.enterPasswordPasswordTextFieldPlaceholder()

        return textField
    }()
    private var exportJsonButton: UIButton { buttonsBar.buttons[0] }
    private let text = PassthroughSubject<String?, Never>()
    private var cancelable = Set<AnyCancellable>()

    private lazy var buttonsBar: HorizontalButtonsBar = {
        let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
        buttonsBar.configure()

        return buttonsBar
    }()

    weak var delegate: ExportJsonKeystorePasswordDelegate?

    init(viewModel: ExportJsonKeystorePasswordViewModel) {
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)

        let edgeInsets = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 16.0, right: 0.0)
        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, edgeInsets: edgeInsets, separatorHeight: 1.0)
        let textFieldLayout = passwordTextField.defaultLayout()
        view.addSubview(textFieldLayout)
        view.addSubview(footerBar)

        NSLayoutConstraint.activate([
            textFieldLayout.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: ScreenChecker.size(big: 34, medium: 34, small: 24)),
            textFieldLayout.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16.0),
            textFieldLayout.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16.0),

            footerBar.anchorsConstraint(to: view)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        bind(viewModel: viewModel)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async { [passwordTextField] in
            passwordTextField.becomeFirstResponder()
        }
    }

    private func bind(viewModel: ExportJsonKeystorePasswordViewModel) {

        let input = ExportJsonKeystorePasswordViewModelInput(
            text: text.eraseToAnyPublisher(),
            exportJson: exportJsonButton.publisher(forEvent: .touchUpInside).eraseToAnyPublisher())

        let output = viewModel.transform(input: input)
        output.viewState
            .sink { [exportJsonButton, navigationItem] viewState in
                exportJsonButton.setTitle(viewState.buttonTitle, for: .normal)
                exportJsonButton.isEnabled = viewState.exportJsonButtonEnabled
                navigationItem.title = viewState.title
            }.store(in: &cancelable)

        output.validatedPassword
            .sink { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.exportKeystoreButtonSelected(with: $0, in: strongSelf)
            }.store(in: &cancelable)
    }
}

extension ExportJsonKeystorePasswordViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        delegate?.didCancel(in: self)
    }
}

extension ExportJsonKeystorePasswordViewController: TextFieldDelegate {

    func doneButtonTapped(for textField: TextField) {
        view.endEditing(true)
    }

    func shouldReturn(in textField: TextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }

    func shouldChangeCharacters(inRange range: NSRange, replacementString string: String, for textField: TextField) -> Bool {
        let result = viewModel.shouldChangeCharacters(text: textField.value, replacementString: string, in: range)
        text.send(result.text)

        return result.shouldChangeCharacters
    }
}
