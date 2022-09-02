//
//  AddMultipleCustomRpcViewController.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 30/12/21.
//

import UIKit
import PromiseKit
import AlphaWalletFoundation

@objc protocol AddMultipleCustomRpcViewControllerResponse: AnyObject {
    @objc func addMultipleCustomRpcCompleted()
    @objc func addMultipleCustomRpcFailed(added: NSArray, failed: NSArray, duplicates: NSArray, remaining: NSArray)
}

@objc protocol HandleAddMultipleCustomRpcViewControllerResponse: AnyObject {
    @objc optional func handleAddMultipleCustomRpcFailure(added: NSArray, failed: NSArray, duplicates: NSArray, remaining: NSArray)
}

class AddMultipleCustomRpcViewController: UIViewController {

    // MARK: - Properties
    // MARK: Private

    private var addCustomChain: AddCustomChain?
    private var currentCustomRpc: CustomRPC?
    private var isCanceled: Bool
    private var viewModel: AddMultipleCustomRpcViewModel
    private var restartQueue: RestartTaskQueue
    private let analytics: AnalyticsLogger

    // MARK: Public

    var progressView: AddMultipleCustomRpcView {
        return view as! AddMultipleCustomRpcView
    }

    weak var delegate: AddMultipleCustomRpcViewControllerResponse?

    // MARK: - Constructor

    init(model: AddMultipleCustomRpcModel, analytics: AnalyticsLogger, restartQueue: RestartTaskQueue) {
        let viewModel = AddMultipleCustomRpcViewModel(model: model)
        self.viewModel = viewModel
        self.isCanceled = false
        self.analytics = analytics
        self.restartQueue = restartQueue
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        configureViewController()
    }

    override func loadView() {
        view = AddMultipleCustomRpcView(frame: .zero)
    }

    // MARK: - Configuration

    private func configureViewController() {
        progressView.addCancelButtonTarget(self, action: #selector(handleCancelAction))
    }

    // MARK: - Obj functions

    @objc func handleCancelAction() {
        isCanceled = true
    }

    // MARK: - Public interface

    func start() {
        self.progressView.startActivityIndicator()
        processRemainingCustomRpcs()
    }

    // MARK: - Private functions

    private func processRemainingCustomRpcs() {
        DispatchQueue.main.async { self.updateProgressView() }
        if !viewModel.model.remainingCustomRpc.isEmpty && !isCanceled {
            addCustomChainSerially()
        } else {
            completeProcessingRemainingCustomRpcs()
        }
    }

    private func addCustomChainSerially() {
        guard let customRpc = viewModel.model.remainingCustomRpc.first else {
            completeProcessingRemainingCustomRpcs()
            return
        }
        currentCustomRpc = customRpc
        if isAlreadyAdded(customRpc: customRpc) {
            handleAddChainCompletion(array: &viewModel.model.duplicateCustomRpc)
        } else {
            startAddChain(for: customRpc)
        }
    }

    private func startAddChain(for customRpc: CustomRPC) {
        let chain = AddCustomChain(customRpc, analytics: analytics, restartQueue: restartQueue)
        chain.delegate = self
        chain.run()
    }

    private func completeProcessingRemainingCustomRpcs() {
        progressView.stopActivityIndicator()
        dismiss(animated: true) {
            if !self.viewModel.hasError {
                self.delegate?.addMultipleCustomRpcCompleted()
            } else {
                self.delegate?.addMultipleCustomRpcFailed(added: self.viewModel.model.addedCustomRpc as NSArray, failed: self.viewModel.model.failedCustomRpc as NSArray, duplicates: self.viewModel.model.duplicateCustomRpc as NSArray, remaining: self.viewModel.model.remainingCustomRpc as NSArray)
            }
        }
    }

    private func updateProgressView() {
        progressView.chainNameString = currentCustomRpc?.chainName ?? "…"
        progressView.progressString = viewModel.progressString
        progressView.progress = viewModel.progress
        progressView.update()
    }

    private func isAlreadyAdded(customRpc: CustomRPC) -> Bool {
        return RPCServer.availableServers.firstIndex(where: { item in
            item.chainID == customRpc.chainID
        }) != nil
    }

}

extension AddMultipleCustomRpcViewController: UIViewControllerTransitioningDelegate {

    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return AddMultipleCustomRpcPresentationController(presentedViewController: presented, presenting: presenting)
    }

}

extension AddMultipleCustomRpcViewController: AddCustomChainDelegate {

    func notifyAddCustomChainQueuedSuccessfully(in addCustomChain: AddCustomChain) {
        handleAddChainCompletion(array: &viewModel.model.addedCustomRpc)
    }

    func notifyAddCustomChainFailed(error: AddCustomChainError, in addCustomChain: AddCustomChain) {
        handleAddChainCompletion(array: &viewModel.model.failedCustomRpc)
    }

    func notifyAddExplorerApiHostnameFailure(customChain: WalletAddEthereumChainObject, chainId: Int) -> Promise<Bool> {
        return Promise { seal in
            seal.fulfill(true)
        }
    }

    func notifyRpcURlHostnameFailure() {
        handleAddChainCompletion(array: &viewModel.model.failedCustomRpc)
    }

    private func handleAddChainCompletion(array: inout [CustomRPC]) {
        if let currentRPC = currentCustomRpc {
            viewModel.model.remainingCustomRpc.removeAll { network in
                network.chainID == currentRPC.chainID
            }
            array.append(currentRPC)
        }
        DispatchQueue.main.async { self.processRemainingCustomRpcs() }
    }

}

extension AddCustomChain {

    convenience init(_ customRpc: CustomRPC, analytics: AnalyticsLogger, restartQueue: RestartTaskQueue) {
        let defaultDecimals = 18
        let explorerEndpoints: [String]?

        if let endpoint = customRpc.explorerEndpoint {
            explorerEndpoints = [endpoint]
        } else {
            explorerEndpoints = nil
        }

        let customChain = WalletAddEthereumChainObject(nativeCurrency: .init(name: customRpc.nativeCryptoTokenName ?? R.string.localizable.addCustomChainUnnamed(), symbol: customRpc.symbol ?? "", decimals: defaultDecimals), blockExplorerUrls: explorerEndpoints, chainName: customRpc.chainName, chainId: String(customRpc.chainID), rpcUrls: [customRpc.rpcEndpoint])

        self.init(customChain, analytics: analytics, isTestnet: customRpc.isTestnet, restartQueue: restartQueue, url: nil, operation: .add, chainNameFallback: R.string.localizable.addCustomChainUnnamed())
    }

}
