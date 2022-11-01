//
//  RenameWalletViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.03.2021.
//

import UIKit
import Combine
import AlphaWalletAddress

protocol RenameWalletViewControllerDelegate: AnyObject {
    func didFinish(in viewController: RenameWalletViewController)
}

class RenameWalletViewController: UIViewController {
    private let viewModel: RenameWalletViewModel
    private var cancelable = Set<AnyCancellable>()
    private lazy var nameTextField: TextField = {
        let textField: TextField = .textField
        textField.label.translatesAutoresizingMaskIntoConstraints = false
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.textField.autocorrectionType = .no
        textField.textField.autocapitalizationType = .none
        textField.returnKeyType = .done
        textField.isSecureTextEntry = false

        return textField
    }()
    private let buttonsBar: HorizontalButtonsBar = {
        let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
        buttonsBar.configure()

        return buttonsBar
    }()
    private var footerBottomConstraint: NSLayoutConstraint!
    private lazy var keyboardChecker = KeyboardChecker(self)
    private let name = PassthroughSubject<String, Never>()
    private let appear = PassthroughSubject<Void, Never>()

    weak var delegate: RenameWalletViewControllerDelegate?

    init(viewModel: RenameWalletViewModel) {
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, edgeInsets: .zero, separatorHeight: 0.0)

        footerBottomConstraint = footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        footerBottomConstraint.constant = -UIApplication.shared.bottomSafeAreaHeight
        keyboardChecker.constraints = [footerBottomConstraint]

        let stackview = [
            nameTextField.label,
            .spacer(height: 4),
            nameTextField,
            .spacer(height: 4),
            nameTextField.statusLabel
        ].asStackView(axis: .vertical)

        stackview.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackview)
        view.addSubview(footerBar)

        NSLayoutConstraint.activate([
            stackview.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stackview.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stackview.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stackview.bottomAnchor.constraint(lessThanOrEqualTo: footerBar.topAnchor),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBottomConstraint,
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        bind(viewModel: viewModel)
    }

    @objc private func tapSelected(_ sender: UITapGestureRecognizer) {
        view.endEditing(true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        keyboardChecker.viewWillAppear()
        appear.send(())
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        keyboardChecker.viewWillDisappear()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func bind(viewModel: RenameWalletViewModel) {
        view.backgroundColor = viewModel.backgroundColor
        nameTextField.label.text = viewModel.walletNameTitle
        buttonsBar.buttons[0].setTitle(viewModel.saveWalletNameTitle, for: .normal)

        let saveWalletName = buttonsBar.buttons[0].publisher(forEvent: .touchUpInside)
            .map { [nameTextField] _ in nameTextField.value }
            .eraseToAnyPublisher()

        let input = RenameWalletViewModelInput(appear: appear.eraseToAnyPublisher(), saveWalletName: saveWalletName)
        let output = viewModel.transform(input: input)

        output.viewState
            .sink { [nameTextField, navigationItem] viewState in
                nameTextField.textField.placeholder = viewState.placeholder
                nameTextField.textField.text = viewState.text
                navigationItem.title = viewState.title
            }.store(in: &cancelable)

        output.walletNameSaved
            .sink { _ in self.delegate?.didFinish(in: self) }
            .store(in: &cancelable)

        view.publisher(for: UITapGestureRecognizer())
            .sink { [weak self] _ in self?.view.endEditing(true) }
            .store(in: &cancelable)
    }
}

extension RenameWalletViewController: TextFieldDelegate {

    func shouldReturn(in textField: TextField) -> Bool {
        view.endEditing(true)
        return true
    }

    func doneButtonTapped(for textField: TextField) {
        //no-op
    }

    func nextButtonTapped(for textField: TextField) {
        //no-op
    }
}
