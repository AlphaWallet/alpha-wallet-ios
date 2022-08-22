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
    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
    private var footerBottomConstraint: NSLayoutConstraint!
    private lazy var keyboardChecker = KeyboardChecker(self)
    private let roundedBackground = RoundedBackground()
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

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        roundedBackground.addSubview(stackview)
        roundedBackground.addSubview(footerBar)

        NSLayoutConstraint.activate([
            stackview.topAnchor.constraint(equalTo: roundedBackground.safeAreaLayoutGuide.topAnchor, constant: 20),
            stackview.leadingAnchor.constraint(equalTo: roundedBackground.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stackview.trailingAnchor.constraint(equalTo: roundedBackground.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stackview.bottomAnchor.constraint(lessThanOrEqualTo: footerBar.topAnchor),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBottomConstraint,
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        buttonsBar.configure()
        buttonsBar.buttons[0].addTarget(self, action: #selector(saveWalletNameSelected), for: .touchUpInside)

        bind(viewModel: viewModel)

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapSelected))
        roundedBackground.addGestureRecognizer(tap)
    }

    @objc private func tapSelected(_ sender: UITapGestureRecognizer) {
        view.endEditing(true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        keyboardChecker.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        keyboardChecker.viewWillDisappear()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func bind(viewModel: RenameWalletViewModel) {
        navigationItem.title = viewModel.title
        nameTextField.label.text = viewModel.walletNameTitle
        buttonsBar.buttons[0].setTitle(viewModel.saveWalletNameTitle, for: .normal)

        viewModel.resolvedEns
            .assign(to: \.placeholder, on: nameTextField.textField)
            .store(in: &cancelable)

        viewModel.assignedName
            .assign(to: \.text, on: nameTextField.textField)
            .store(in: &cancelable)
    }

    @objc private func saveWalletNameSelected(_ sender: UIButton) {
        viewModel.set(walletName: nameTextField.value)

        delegate?.didFinish(in: self)
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
