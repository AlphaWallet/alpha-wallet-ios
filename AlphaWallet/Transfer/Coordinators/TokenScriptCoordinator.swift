//
//  TokenScriptCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 13.12.2021.
//

import UIKit
import BigInt
import Result
import Combine

protocol TokenScriptCoordinatorDelegate: CanOpenURL, SendTransactionDelegate {
    func didFinish(_ result: ConfirmResult, in coordinator: TokenScriptCoordinator)
    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: TokenScriptCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource)
    func didCancel(in coordinator: TokenScriptCoordinator)
}

class TokenScriptCoordinator: Coordinator {
    private lazy var viewController: TokenInstanceActionViewController = {
        return makeTokenInstanceActionViewController(token: tokenObject, for: tokenHolder, action: action)
    }()

    private let keystore: Keystore
    private let tokenObject: TokenObject
    private let session: WalletSession
    private let assetDefinitionStore: AssetDefinitionStore
    private let analyticsCoordinator: AnalyticsCoordinator
    private let domainResolutionService: DomainResolutionServiceType
    private let tokenHolder: TokenHolder
    private var transactionConfirmationResult: ConfirmResult? = .none
    private let action: TokenInstanceAction
    private let tokensStorage: TokensDataStore
    private let eventsDataStore: NonActivityEventsDataStore
    private var cancelable = Set<AnyCancellable>()

    weak var delegate: TokenScriptCoordinatorDelegate?
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []

    init(
            session: WalletSession,
            navigationController: UINavigationController,
            keystore: Keystore,
            tokenHolder: TokenHolder,
            tokensStorage: TokensDataStore,
            tokenObject: TokenObject,
            assetDefinitionStore: AssetDefinitionStore,
            analyticsCoordinator: AnalyticsCoordinator,
            domainResolutionService: DomainResolutionServiceType,
            action: TokenInstanceAction,
            eventsDataStore: NonActivityEventsDataStore
    ) {
        self.eventsDataStore = eventsDataStore
        self.action = action
        self.tokenHolder = tokenHolder
        self.session = session
        self.keystore = keystore
        self.navigationController = navigationController
        self.tokenObject = tokenObject
        self.assetDefinitionStore = assetDefinitionStore
        self.analyticsCoordinator = analyticsCoordinator
        self.domainResolutionService = domainResolutionService
        self.tokensStorage = tokensStorage
        navigationController.navigationBar.isTranslucent = false
    }

    func start() {
        viewController.navigationItem.largeTitleDisplayMode = .never
        viewController.navigationItem.leftBarButtonItem = UIBarButtonItem.backBarButton(self, selector: #selector(dismiss))
        navigationController.pushViewController(viewController, animated: true)

        subscribeForEthereumEventChanges()
    }

    @objc private func dismiss() {
        removeAllCoordinators()

        delegate?.didCancel(in: self)
    }

    private func makeTokenInstanceActionViewController(token: TokenObject, for tokenHolder: TokenHolder, action: TokenInstanceAction) -> TokenInstanceActionViewController {
        let vc = TokenInstanceActionViewController(analyticsCoordinator: analyticsCoordinator, tokenObject: tokenObject, tokenHolder: tokenHolder, tokensStorage: tokensStorage, assetDefinitionStore: assetDefinitionStore, action: action, session: session, keystore: keystore)
        vc.delegate = self
        vc.configure()

        return vc
    }

    private func subscribeForEthereumEventChanges() {
        eventsDataStore
            .recentEventsChangeset(for: tokenObject.contractAddress)
            .filter({ changeset in
                switch changeset {
                case .update(let events, _, let insertions, let modifications):
                    return !insertions.map { events[$0] }.isEmpty || !modifications.map { events[$0] }.isEmpty
                case .initial, .error:
                    return false
                }
            })
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] _ in
                self?.viewController.configure()
            }).store(in: &cancelable)

        assetDefinitionStore
            .assetsSignatureOrBodyChange(for: tokenObject.contractAddress)
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] _ in
                self?.viewController.configure()
            }).store(in: &cancelable)
    }
}

extension TokenScriptCoordinator: TokenInstanceActionViewControllerDelegate {

    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }

    func confirmTransactionSelected(in viewController: TokenInstanceActionViewController, tokenObject: TokenObject, contract: AlphaWallet.Address, tokenId: TokenId, values: [AttributeId: AssetInternalValue], localRefs: [AttributeId: AssetInternalValue], server: RPCServer, session: WalletSession, keystore: Keystore, transactionFunction: FunctionOrigin) {
        guard let navigationController = viewController.navigationController else { return }

        do {
            let data = try transactionFunction.makeUnConfirmedTransaction(withTokenObject: tokenObject, tokenId: tokenId, attributeAndValues: values, localRefs: localRefs, server: server, session: session)
            let coordinator = try TransactionConfirmationCoordinator(presentingViewController: navigationController, session: session, transaction: data.0, configuration: .tokenScriptTransaction(confirmType: .signThenSend, contract: contract, keystore: keystore, functionCallMetaData: data.1), analyticsCoordinator: analyticsCoordinator, domainResolutionService: domainResolutionService)
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

    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: AnyError) {
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

    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: TransactionConfirmationCoordinator, viewController: UIViewController) {
        delegate?.openFiatOnRamp(wallet: wallet, server: server, inCoordinator: self, viewController: viewController, source: .transactionActionSheetInsufficientFunds)
    }
}

extension TokenScriptCoordinator: TransactionInProgressCoordinatorDelegate {
    func didDismiss(in coordinator: TransactionInProgressCoordinator) {
        removeCoordinator(coordinator)

        guard case .some(let result) = transactionConfirmationResult else { return }
        delegate?.didFinish(result, in: self)
    }
}
