//
//  AddRPCServerViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.06.2021.
//

import UIKit

protocol AddRPCServerViewControllerDelegate: AnyObject {
    func didFinish(in viewController: AddRPCServerViewController, rpc: CustomRPC)
}

class AddRPCServerViewController: UIViewController {

    private let viewModel: AddrpcServerViewModel
    private var config: Config

    private lazy var networkNameTextField: TextField = {
        let textField = TextField()
        textField.label.translatesAutoresizingMaskIntoConstraints = false
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.textField.autocorrectionType = .no
        textField.textField.autocapitalizationType = .none
        textField.returnKeyType = .next
        textField.placeholder = R.string.localizable.addrpcServerNetworkNameTitle()

        return textField
    }()

    private lazy var rpcUrlTextField: TextField = {
        let textField = TextField()
        textField.label.translatesAutoresizingMaskIntoConstraints = false
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.textField.autocorrectionType = .no
        textField.textField.autocapitalizationType = .none
        textField.returnKeyType = .next
        textField.keyboardType = .URL
        textField.placeholder = R.string.localizable.addrpcServerRpcUrlPlaceholder()

        return textField
    }()

    private lazy var chainIDTextField: TextField = {
        let textField = TextField()
        textField.label.translatesAutoresizingMaskIntoConstraints = false
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.textField.autocorrectionType = .no
        textField.textField.autocapitalizationType = .none
        textField.returnKeyType = .next
        textField.keyboardType = .decimalPad
        textField.placeholder = R.string.localizable.chainID()

        return textField
    }()

    private lazy var symbolTextField: TextField = {
        let textField = TextField()
        textField.label.translatesAutoresizingMaskIntoConstraints = false
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.textField.autocorrectionType = .no
        textField.textField.autocapitalizationType = .none
        textField.returnKeyType = .next
        textField.placeholder = R.string.localizable.symbol()

        return textField
    }()

    private lazy var blockExplorerURLTextField: TextField = {
        let textField = TextField()
        textField.label.translatesAutoresizingMaskIntoConstraints = false
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.textField.autocorrectionType = .no
        textField.textField.autocapitalizationType = .none
        textField.returnKeyType = .done
        textField.keyboardType = .URL
        textField.placeholder = R.string.localizable.addrpcServerBlockExplorerUrlPlaceholder()

        return textField
    }()

    private lazy var isTestNetworkView: SwitchView = {
        let view = SwitchView()
        view.delegate = self

        return view
    }()

    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))
    private var scrollViewBottomConstraint: NSLayoutConstraint!
    private lazy var keyboardChecker = KeyboardChecker(self)
    private let roundedBackground = RoundedBackground()
    private let scrollView = UIScrollView()

    weak var delegate: AddRPCServerViewControllerDelegate?

    static func layoutSubviews(for textField: TextField) -> [UIView] {
        [textField.label, .spacer(height: 4), textField, .spacer(height: 4), textField.statusLabel, .spacer(height: 24)]
    }

    init(viewModel: AddrpcServerViewModel, config: Config) {
        self.viewModel = viewModel
        self.config = config

        super.init(nibName: nil, bundle: nil)

        scrollViewBottomConstraint = scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        scrollViewBottomConstraint.constant = -UIApplication.shared.bottomSafeAreaHeight
        keyboardChecker.constraint = scrollViewBottomConstraint

        let stackView = (
            Self.layoutSubviews(for: networkNameTextField) +
            Self.layoutSubviews(for: rpcUrlTextField) +
            Self.layoutSubviews(for: chainIDTextField) +
            Self.layoutSubviews(for: symbolTextField) +
            Self.layoutSubviews(for: blockExplorerURLTextField) +
            [
                isTestNetworkView,
                .spacer(height: 40)
            ]
        ).asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(scrollView)

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, edgeInsets: .zero, separatorHeight: 0.0)
        scrollView.addSubview(footerBar)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollViewBottomConstraint,

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))

        hidesBottomBarWhenPushed = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        buttonsBar.configure()
        networkNameTextField.configureOnce()
        rpcUrlTextField.configureOnce()
        chainIDTextField.configureOnce()
        symbolTextField.configureOnce()
        blockExplorerURLTextField.configureOnce()
        isTestNetworkView.configure(viewModel: viewModel.enableServersHeaderViewModel)

        buttonsBar.buttons[0].addTarget(self, action: #selector(saveCustomRPC), for: .touchUpInside)

        configure(viewModel: viewModel)

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

    func configure(viewModel: AddrpcServerViewModel) {
        navigationItem.title = viewModel.title

        networkNameTextField.label.text = viewModel.networkNameTitle
        rpcUrlTextField.label.text = viewModel.rpcUrlTitle
        chainIDTextField.label.text = viewModel.chainIDTitle
        symbolTextField.label.text = viewModel.symbolTitle
        blockExplorerURLTextField.label.text = viewModel.blockExplorerURLTitle

        buttonsBar.buttons[0].setTitle(viewModel.saverpcServerTitle, for: .normal)
    }

    private func validateInputs() -> Bool {
        var isValid: Bool = true

        if networkNameTextField.value.trimmed.isEmpty {
            isValid = false
            networkNameTextField.status = .error(R.string.localizable.addrpcServerNetworkNameError())
        } else {
            networkNameTextField.status = .none
        }

        if URL(string: rpcUrlTextField.value.trimmed) == nil {
            isValid = false
            rpcUrlTextField.status = .error(R.string.localizable.addrpcServerRpcUrlError())
        } else {
            rpcUrlTextField.status = .none
        }

        if let chainId = Int(chainId0xString: chainIDTextField.value.trimmed), chainId > 0 {
            if config.enabledServers.contains(where: { $0.chainID == chainId }) {
                isValid = false
                //TODO maybe a prompt with button to enable it instead?
                chainIDTextField.status = .error(R.string.localizable.addrpcServerChainIdAlreadySupported())
            } else {
                chainIDTextField.status = .none
            }

        } else {
            isValid = false
            chainIDTextField.status = .error(R.string.localizable.addrpcServerChainIDError())
        }

        if symbolTextField.value.trimmed.isEmpty {
            isValid = false
            symbolTextField.status = .error(R.string.localizable.addrpcServerSymbolError())
        } else {
            symbolTextField.status = .none
        }

        if URL(string: blockExplorerURLTextField.value.trimmed) == nil {
            isValid = false
            blockExplorerURLTextField.status = .error(R.string.localizable.addrpcServerBlockExplorerUrlError())
        } else {
            blockExplorerURLTextField.status = .none
        }

        return isValid
    }

    @objc private func saveCustomRPC(_ sender: UIButton) {
        guard validateInputs() else { return }

        let customRPC = CustomRPC(
            chainID: Int(chainId0xString: chainIDTextField.value.trimmed)!,
            nativeCryptoTokenName: nil,
            chainName: networkNameTextField.value.trimmed,
            symbol: symbolTextField.value.trimmed,
            rpcEndpoint: rpcUrlTextField.value.trimmed,
            explorerEndpoint: blockExplorerURLTextField.value.trimmed,
            etherscanCompatibleType: .unknown,
            isTestnet: isTestNetworkView.isOn
        )

        delegate?.didFinish(in: self, rpc: customRPC)
    }
}

extension AddRPCServerViewController: SwitchViewDelegate {
    func toggledTo(_ newValue: Bool, headerView: SwitchView) {
        //no-op
    }
}

extension AddRPCServerViewController: TextFieldDelegate {

    func shouldReturn(in textField: TextField) -> Bool {
        switch textField {
        case networkNameTextField:
            rpcUrlTextField.becomeFirstResponder()
        case rpcUrlTextField:
            chainIDTextField.becomeFirstResponder()
        case chainIDTextField:
            symbolTextField.becomeFirstResponder()
        case symbolTextField:
            blockExplorerURLTextField.becomeFirstResponder()
        case blockExplorerURLTextField:
            view.endEditing(true)
        default:
            view.endEditing(true)
        }
        return true
    }

    func doneButtonTapped(for textField: TextField) {
        //no-op
    }

    func nextButtonTapped(for textField: TextField) {
        //no-op
    }
}
