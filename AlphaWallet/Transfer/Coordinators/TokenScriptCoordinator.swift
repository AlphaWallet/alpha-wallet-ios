//
//  TokenScriptCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 13.12.2021.
//

import UIKit
import BigInt
import Combine
import AlphaWalletFoundation

protocol TokenScriptCoordinatorDelegate: CanOpenURL, SendTransactionDelegate, BuyCryptoDelegate {
    func didFinish(_ result: ConfirmResult, in coordinator: TokenScriptCoordinator)
    func didCancel(in coordinator: TokenScriptCoordinator)
}

class TokenScriptCoordinator: Coordinator {
    private lazy var viewController: TokenInstanceActionViewController = {
        return makeTokenInstanceActionViewController(token: token, for: tokenHolder, action: action)
    }()

    private let keystore: Keystore
    private let token: Token
    private let session: WalletSession
    private let assetDefinitionStore: AssetDefinitionStore
    private let analytics: AnalyticsLogger
    private let domainResolutionService: DomainResolutionServiceType
    private let tokenHolder: TokenHolder
    private var transactionConfirmationResult: ConfirmResult? = .none
    private let action: TokenInstanceAction
    private var cancelable = Set<AnyCancellable>()
    private let tokensService: TokenViewModelState
    weak var delegate: TokenScriptCoordinatorDelegate?
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []

    init(
            session: WalletSession,
            navigationController: UINavigationController,
            keystore: Keystore,
            tokenHolder: TokenHolder,
            tokenObject: Token,
            assetDefinitionStore: AssetDefinitionStore,
            analytics: AnalyticsLogger,
            domainResolutionService: DomainResolutionServiceType,
            action: TokenInstanceAction,
            tokensService: TokenViewModelState
    ) {
        self.tokensService = tokensService
        self.action = action
        self.tokenHolder = tokenHolder
        self.session = session
        self.keystore = keystore
        self.navigationController = navigationController
        self.token = tokenObject
        self.assetDefinitionStore = assetDefinitionStore
        self.analytics = analytics
        self.domainResolutionService = domainResolutionService
        navigationController.navigationBar.isTranslucent = false
    }

    func start() {
        viewController.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(viewController, animated: true)

        subscribeForEthereumEventChanges()
    }

    private func makeTokenInstanceActionViewController(token: Token, for tokenHolder: TokenHolder, action: TokenInstanceAction) -> TokenInstanceActionViewController {
        let vc = TokenInstanceActionViewController(analytics: analytics, token: token, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore, action: action, session: session, keystore: keystore)
        vc.delegate = self
        vc.configure()

        return vc
    }
    //FIXME: Move to view model
    private func subscribeForEthereumEventChanges() {
        tokensService.tokenViewModelPublisher(for: token).sink { [weak self] _ in
            self?.viewController.configure()
        }.store(in: &cancelable)
    }
}

extension TokenScriptCoordinator: TokenInstanceActionViewControllerDelegate {

    func didClose(in viewController: TokenInstanceActionViewController) {
        delegate?.didCancel(in: self)
    }

    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }

    func confirmTransactionSelected(in viewController: TokenInstanceActionViewController, token: Token, contract: AlphaWallet.Address, tokenId: TokenId, values: [AttributeId: AssetInternalValue], localRefs: [AttributeId: AssetInternalValue], server: RPCServer, session: WalletSession, keystore: Keystore, transactionFunction: FunctionOrigin) {
        guard let navigationController = viewController.navigationController else { return }

        do {
            let data = try transactionFunction.makeUnConfirmedTransaction(withTokenObject: token, tokenId: tokenId, attributeAndValues: values, localRefs: localRefs, server: server, session: session)
            let coordinator = try TransactionConfirmationCoordinator(presentingViewController: navigationController, session: session, transaction: data.0, configuration: .tokenScriptTransaction(confirmType: .signThenSend, contract: contract, functionCallMetaData: data.1), analytics: analytics, domainResolutionService: domainResolutionService, keystore: keystore, assetDefinitionStore: assetDefinitionStore, tokensService: tokensService)
            coordinator.delegate = self
            addCoordinator(coordinator)
            coordinator.start(fromSource: .tokenScript)
        } catch {
            UIApplication.shared
                .presentedViewController(or: navigationController)
                .displayError(message: error.prettyError)
        }
    }

    func didPressViewRedemptionInfo(in viewController: TokenInstanceActionViewController) {
        showViewRedemptionInfo(in: viewController)
    }

    func shouldCloseFlow(inViewController viewController: TokenInstanceActionViewController) {
        viewController.navigationController?.popViewController(animated: true)
    }

    private func showViewRedemptionInfo(in viewController: UIViewController) {
        let controller = TokenCardRedemptionInfoViewController(delegate: self)
        controller.navigationItem.largeTitleDisplayMode = .never

        viewController.navigationController?.pushViewController(controller, animated: true)
    }
}

extension TokenScriptCoordinator: StaticHTMLViewControllerDelegate {

}

extension TokenScriptCoordinator: TransactionConfirmationCoordinatorDelegate {

    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: Error) {
        UIApplication.shared
            .presentedViewController(or: navigationController)
            .displayError(message: error.prettyError)
    }

    func didClose(in coordinator: TransactionConfirmationCoordinator) {
        removeCoordinator(coordinator)
    }

    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: TransactionConfirmationCoordinator) {
        delegate?.didSendTransaction(transaction, inCoordinator: coordinator)
    }

    func didFinish(_ result: ConfirmResult, in coordinator: TransactionConfirmationCoordinator) {
        coordinator.close { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.removeCoordinator(coordinator)
            strongSelf.transactionConfirmationResult = result

            let coordinator = TransactionInProgressCoordinator(presentingViewController: strongSelf.navigationController)
            coordinator.delegate = strongSelf
            strongSelf.addCoordinator(coordinator)

            coordinator.start()
        }
    }

    func buyCrypto(wallet: Wallet, server: RPCServer, viewController: UIViewController, source: Analytics.BuyCryptoSource) {
        delegate?.buyCrypto(wallet: wallet, server: server, viewController: viewController, source: .transactionActionSheetInsufficientFunds)
    }
}

extension TokenScriptCoordinator: TransactionInProgressCoordinatorDelegate {
    func didDismiss(in coordinator: TransactionInProgressCoordinator) {
        removeCoordinator(coordinator)

        guard case .some(let result) = transactionConfirmationResult else { return }
        delegate?.didFinish(result, in: self)
    }
}
