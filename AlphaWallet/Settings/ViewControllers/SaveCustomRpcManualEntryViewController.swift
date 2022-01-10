//
//  SaveCustomRpcManualEntryViewController.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 7/11/21.
//

import UIKit

protocol SaveCustomRpcEntryViewControllerDataDelegate: AnyObject {
    func didFinish(in viewController: SaveCustomRpcManualEntryViewController, customRpc: CustomRPC)
}

protocol SaveCustomRpcHandleUrlFailure: AnyObject {
    func handleRpcUrlFailure()
}

class SaveCustomRpcManualEntryViewController: UIViewController, SaveCustomRpcHandleUrlFailure {

    private lazy var keyboardChecker: KeyboardChecker = KeyboardChecker(self)
    private let viewModel: SaveCustomRpcManualEntryViewModel

    weak var dataDelegate: SaveCustomRpcEntryViewControllerDataDelegate?
    var editView: SaveCustomRpcManualEntryView {
        return view as! SaveCustomRpcManualEntryView
    }

    init(viewModel: SaveCustomRpcManualEntryViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SaveCustomRpcManualEntryView(frame: .zero, isEmbedded: viewModel.isAddOperation)
        view.isHidden = viewModel.isAddOperation
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
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
    }

    func handleRpcUrlFailure() {
        editView.rpcEndPointTextField.status = .error(R.string.localizable.addrpcServerRpcUrlError(preferredLanguages: Languages.preferred()))
        editView.rpcEndPointTextField.becomeFirstResponder()
    }

    private func configure() {
        editView.chainNameTextField.value = viewModel.chainName
        editView.chainNameTextField.delegate = self

        editView.rpcEndPointTextField.value = viewModel.rpcEndPoint
        editView.rpcEndPointTextField.delegate = self

        editView.chainIDTextField.value = viewModel.chainID
        editView.chainIDTextField.delegate = self

        editView.symbolTextField.value = viewModel.symbol
        editView.symbolTextField.delegate = self

        editView.explorerEndpointTextField.value = viewModel.explorerEndpoint
        editView.explorerEndpointTextField.delegate = self

        editView.configureView()

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapSelected))
        editView.addBackgroundGestureRecognizer(tap)
        editView.isTestNetworkView.configure(viewModel: SwitchViewViewModel(text: R.string.localizable.addrpcServerIsTestnetTitle(preferredLanguages: Languages.preferred()), isOn: viewModel.isTestnet))
        if viewModel.isEditOperation {
            editView.configureKeyboard(keyboardChecker: keyboardChecker)
        }
        editView.addSaveButtonTarget(self, action: #selector(handleSaveCustomRPC))
    }

    @objc private func tapSelected(_ sender: UITapGestureRecognizer) {
        view.endEditing(true)
    }

    @objc private func handleSaveCustomRPC(_ sender: UIButton) {
        saveCustomRPC()
    }

    private func saveCustomRPC() {
        let result = viewModel.validate(
            chainName: editView.chainNameTextField.value,
            rpcEndpoint: editView.rpcEndPointTextField.value,
            chainID: editView.chainIDTextField.value,
            symbol: editView.symbolTextField.value,
            explorerEndpoint: editView.explorerEndpointTextField.value,
            isTestNet: editView.isTestNetworkView.isOn)
        view.endEditing(true)
        switch result {
        case .failure(.list(let errors)):
            handleValidationFailure(errors: errors)
        case .success(let customRPC):
            handleValidationSuccess(customRPC: customRPC)
        }
    }

    private func handleValidationFailure(errors: [SaveCustomRpcError]) {
        editView.resetAllTextFieldStatus()
        for error in errors {
            switch error {
            case .chainNameInvalidField:
                editView.chainNameTextField.status = .error(R.string.localizable.addrpcServerNetworkNameError(preferredLanguages: Languages.preferred()))
            case .rpcEndPointInvalidField:
                editView.rpcEndPointTextField.status = .error(R.string.localizable.addrpcServerRpcUrlError(preferredLanguages: Languages.preferred()))
            case .chainIDInvalidField:
                editView.chainIDTextField.status = .error(R.string.localizable.addrpcServerChainIDError(preferredLanguages: Languages.preferred()))
            case .symbolInvalidField:
                editView.symbolTextField.status = .error(R.string.localizable.addrpcServerSymbolError(preferredLanguages: Languages.preferred()))
            case .explorerEndpointInvalidField:
                editView.explorerEndpointTextField.status = .error(R.string.localizable.addrpcServerBlockExplorerUrlError(preferredLanguages: Languages.preferred()))
            case .chainIDDuplicateField:
                editView.chainIDTextField.status = .error(R.string.localizable.editCustomRPCChainIDErrorDuplicate(preferredLanguages: Languages.preferred()))
            }
        }
        editView.allTextFields.first(where: { !$0.statusLabel.text.isEmpty })?.becomeFirstResponder()
    }

    private func handleValidationSuccess(customRPC: CustomRPC) {
        editView.resetAllTextFieldStatus()
        dataDelegate?.didFinish(in: self, customRpc: customRPC)
    }

}

extension SaveCustomRpcManualEntryViewController: TextFieldDelegate {

    func shouldReturn(in textField: TextField) -> Bool {
        switch textField {
        case editView.explorerEndpointTextField:
            view.endEditing(true)
            saveCustomRPC()
        default:
            editView.gotoNextResponder()
        }
        return true
    }

    func didBeginEditing(in textField: TextField) {
        DispatchQueue.main.async {
            self.editView.unobscure(textField: textField)
        }
    }

    func doneButtonTapped(for textField: TextField) {
        //no-op
    }

    func nextButtonTapped(for textField: TextField) {
        //no-op
    }

}

extension SaveCustomRpcManualEntryViewController: HandleAddMultipleCustomRpcViewControllerResponse {

}
