//
//  EditCustomRPCViewController.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 7/11/21.
//

import UIKit

protocol EditCustomRPCViewControllerDelegate: AnyObject {
    func didFinish(in viewController: EditCustomRPCViewController, customRPC: CustomRPC)
}

class EditCustomRPCViewController: UIViewController {
    let viewModel: EditCustomRPCViewModel
    var editView: EditCustomRPCView!
    private lazy var keyboardChecker: KeyboardChecker = KeyboardChecker(self)
    weak var delegate: EditCustomRPCViewControllerDelegate?

    init(viewModel: EditCustomRPCViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        let rootView = EditCustomRPCView(frame: .zero)
        view = rootView
        editView = rootView
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
        editView.isTestNetworkView.configure(viewModel: SwitchViewViewModel(text: R.string.localizable.addrpcServerIsTestnetTitle(), isOn: viewModel.isTestnet))
        editView.configureKeyboard(keyboardChecker: keyboardChecker)
        editView.addSaveButtonTarget(self, action: #selector(saveCustomRPC))
        
        navigationItem.title = R.string.localizable.editCustomRPCNavigationTitle(preferredLanguages: nil)
    }
    
    @objc private func tapSelected(_ sender: UITapGestureRecognizer) {
        view.endEditing(true)
    }
    
    @objc private func saveCustomRPC(_ sender: UIButton) {
        let result = viewModel.validate(
            chainName: editView.chainNameTextField.value,
            rpcEndpoint: editView.rpcEndPointTextField.value,
            chainID: editView.chainIDTextField.value,
            symbol: editView.symbolTextField.value,
            explorerEndpoint: editView.explorerEndpointTextField.value,
            isTestNet: editView.isTestNetworkView.isOn)
        
        switch result {
        case .failure(.list(let errors)):
            handleValidationFailure(errors: errors)
        case .failure:
            handleValidationFailure(errors: [.unknown])
        case .success(let customRPC):
            handleValidationSuccess(customRPC: customRPC)
        }
    }
    
    private func handleValidationFailure(errors: [EditCustomRPCErrors]) {
        editView.resetAllTextFieldStatus()
        for error in errors {
            switch error {
            case .unknown, .list:
                // ??? TODO: Where do we log the error???
                NSLog("Huh???")
            case .chainNameInvalidField:
                editView.chainNameTextField.status = .error(R.string.localizable.addrpcServerNetworkNameError())
            case .rpcEndPointInvalidField:
                editView.rpcEndPointTextField.status = .error(R.string.localizable.addrpcServerRpcUrlError())
            case .chainIDInvalidField:
                editView.chainIDTextField.status = .error(R.string.localizable.addrpcServerChainIDError())
            case .symbolInvalidField:
                editView.symbolTextField.status = .error(R.string.localizable.addrpcServerSymbolError())
            case .explorerEndpointInvalidField:
                editView.explorerEndpointTextField.status = .error(R.string.localizable.addrpcServerBlockExplorerUrlError())
            case .chainIDDuplicateField:
                editView.chainIDTextField.status = .error(R.string.localizable.editCustomRPCChainIDErrorDuplicate(preferredLanguages: nil))
            }
        }
    }
    
    private func handleValidationSuccess(customRPC: CustomRPC) {
        delegate?.didFinish(in: self, customRPC: customRPC)
    }
}

extension EditCustomRPCViewController: TextFieldDelegate {    
    func shouldReturn(in textField: TextField) -> Bool {
        switch textField {
        case editView.chainNameTextField:
            editView.rpcEndPointTextField.becomeFirstResponder()
        case editView.rpcEndPointTextField:
            editView.chainIDTextField.becomeFirstResponder()
        case editView.chainIDTextField:
            editView.symbolTextField.becomeFirstResponder()
        case editView.symbolTextField:
            editView.explorerEndpointTextField.becomeFirstResponder()
        case editView.explorerEndpointTextField:
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
