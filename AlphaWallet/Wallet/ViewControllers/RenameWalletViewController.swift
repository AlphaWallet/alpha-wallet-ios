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
        let textField = TextField.buildTextField()
        textField.delegate = self
        textField.returnKeyType = .done
        textField.inputAccessoryButtonType = .done
        textField.label.text = R.string.localizable.walletRenameEnterNameTitle()
        textField.placeholder = "Wallet Name"
        
        return textField
    }()
    private let buttonsBar: HorizontalButtonsBar = {
        let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
        buttonsBar.configure()

        return buttonsBar
    }()

    private let willAppear = PassthroughSubject<Void, Never>()

    weak var delegate: RenameWalletViewControllerDelegate?

    init(viewModel: RenameWalletViewModel) {
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0)
        let nameTextFieldLayout = nameTextField.defaultLayout(edgeInsets: .init(top: 20, left: 16, bottom: 0, right: 16))

        view.addSubview(nameTextFieldLayout)
        view.addSubview(footerBar)

        NSLayoutConstraint.activate([
            nameTextFieldLayout.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            nameTextFieldLayout.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            nameTextFieldLayout.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),

            footerBar.anchorsConstraint(to: view)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        buttonsBar.buttons[0].setTitle(R.string.localizable.walletRenameSave(), for: .normal)
        
        bind(viewModel: viewModel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        willAppear.send(())
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func bind(viewModel: RenameWalletViewModel) {

        let walletName = buttonsBar.buttons[0].publisher(forEvent: .touchUpInside)
            .map { [nameTextField] _ in nameTextField.value }
            .eraseToAnyPublisher()

        let input = RenameWalletViewModelInput(
            willAppear: willAppear.eraseToAnyPublisher(),
            walletName: walletName)

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
    }
}

extension RenameWalletViewController: TextFieldDelegate {

    func shouldReturn(in textField: TextField) -> Bool {
        view.endEditing(true)
        return true
    }

    func doneButtonTapped(for textField: TextField) {
        view.endEditing(true)
    }
}
