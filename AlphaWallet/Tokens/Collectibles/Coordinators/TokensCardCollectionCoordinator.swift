//
//  TokensCardCollectionCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import Foundation
import UIKit
import SafariServices
import MessageUI
import BigInt
import Combine

protocol TokensCardCollectionCoordinatorDelegate: class, CanOpenURL {
    func didTap(for type: PaymentFlow, in coordinator: TokensCardCollectionCoordinator, viewController: UIViewController)
    func didTap(transaction: TransactionInstance, in coordinator: TokensCardCollectionCoordinator)
    func didTap(activity: Activity, in coordinator: TokensCardCollectionCoordinator)
    func didClose(in coordinator: TokensCardCollectionCoordinator)
}

class TokensCardCollectionCoordinator: NSObject, Coordinator {
    private let keystore: Keystore
    private let token: TokenObject
    private (set) lazy var rootViewController: TokensCardViewController = {
        return makeTokensCardCollectionViewController()
    }()

    private let session: WalletSession
    private let tokensStorage: TokensDataStore
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: NonActivityEventsDataStore
    private let transactionsStorage: TransactionsStorage

    private (set) var analyticsCoordinator: AnalyticsCoordinator
    private let activitiesService: ActivitiesServiceType
    weak var delegate: TokensCardCollectionCoordinatorDelegate?
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    private let paymantFlow: PaymentFlow
    private var cancelable = Set<AnyCancellable>()

    init(
            session: WalletSession,
            navigationController: UINavigationController,
            keystore: Keystore,
            tokensStorage: TokensDataStore,
            token: TokenObject,
            assetDefinitionStore: AssetDefinitionStore,
            eventsDataStore: NonActivityEventsDataStore,
            analyticsCoordinator: AnalyticsCoordinator,
            activitiesService: ActivitiesServiceType,
            transactionsStorage: TransactionsStorage,
            paymantFlow: PaymentFlow
    ) {
        self.paymantFlow = paymantFlow
        self.session = session
        self.keystore = keystore
        self.navigationController = navigationController
        self.tokensStorage = tokensStorage
        self.token = token
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
        self.analyticsCoordinator = analyticsCoordinator
        self.activitiesService = activitiesService
        self.transactionsStorage = transactionsStorage
        navigationController.navigationBar.isTranslucent = false
    }

    func start() {
        let viewModel = TokensCardViewModel(token: token, forWallet: session.account, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore)
        rootViewController.configure(viewModel: viewModel)
        navigationController.pushViewController(rootViewController, animated: true)
        refreshUponAssetDefinitionChanges()
        refreshUponEthereumEventChanges()
    }

    private func refreshUponEthereumEventChanges() {
        let tokenContract = token.contractAddress
        eventsDataStore
            .recentEvents(forTokenContract: tokenContract)
            .subscribe(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] _ in
                self?.refreshScreen(forContract: tokenContract)
            }).store(in: &cancelable)
    }

    private func refreshUponAssetDefinitionChanges() {
        assetDefinitionStore.subscribeToBodyChanges { [weak self] contract in
            guard let strongSelf = self else { return }
            strongSelf.refreshScreen(forContract: contract)
        }
        assetDefinitionStore.subscribeToSignatureChanges { [weak self] contract in
            guard let strongSelf = self else { return }
            strongSelf.refreshScreen(forContract: contract)
        }
    }

    private func refreshScreen(forContract contract: AlphaWallet.Address) {
        guard contract.sameContract(as: token.contractAddress) else { return }

        for each in navigationController.viewControllers {
            switch each {
            case let vc as TokensCardViewController:
                let viewModel = TokensCardViewModel(token: token, forWallet: session.account, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore)
                vc.configure(viewModel: viewModel)
            case let vc as TokenInstanceViewController:
                let updatedTokenHolders = TokenAdaptor(token: token, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore).getTokenHolders(forWallet: session.account)
                if let selection = vc.isMatchingTokenHolder(fromTokenHolders: updatedTokenHolders) {
                    let viewModel: TokenInstanceViewModel = .init(tokenId: selection.tokenId, token: token, tokenHolder: selection.tokenHolder, assetDefinitionStore: assetDefinitionStore)
                    vc.configure(viewModel: viewModel)
                }
            default:
                break
            }
        }
    }

    private func transactionsFilter(for strategy: ActivitiesFilterStrategy, tokenObject: TokenObject) -> TransactionsFilterStrategy {
        return .filter(transactionsStorage: transactionsStorage, strategy: strategy, tokenObject: tokenObject)
    }

    private func makeTokensCardCollectionViewController() -> TokensCardViewController {
        let viewModel = TokensCardViewModel(token: token, forWallet: session.account, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore)
        let activitiesFilterStrategy: ActivitiesFilterStrategy = .operationTypes(operationTypes: [.erc1155TokenTransfer], contract: token.contractAddress)
        let activitiesService = self.activitiesService.copy(activitiesFilterStrategy: activitiesFilterStrategy, transactionsFilterStrategy: transactionsFilter(for: activitiesFilterStrategy, tokenObject: token))

        let controller = TokensCardViewController(keystore: keystore, session: session, assetDefinition: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator, token: token, viewModel: viewModel, activitiesService: activitiesService, eventsDataStore: eventsDataStore)
        controller.hidesBottomBarWhenPushed = true
        controller.delegate = self
        controller.navigationItem.leftBarButtonItem = .backBarButton(self, selector: #selector(didCloseSelected))

        return controller
    }

    @objc private func didCloseSelected(_ sender: UIBarButtonItem) {
        navigationController.popViewController(animated: true)
        delegate?.didClose(in: self)
    }

    func stop() {
        session.stop()
    }

    private func makeTokenInstanceViewController(tokenHolder: TokenHolder, tokenId: TokenId, mode: TokenInstanceViewMode) -> TokenInstanceViewController {
        let vc = TokenInstanceViewController(analyticsCoordinator: analyticsCoordinator, tokenObject: token, tokenHolder: tokenHolder, tokenId: tokenId, account: session.account, assetDefinitionStore: assetDefinitionStore, mode: mode)
        vc.delegate = self
        vc.configure()
        vc.navigationItem.largeTitleDisplayMode = .never
        vc.navigationItem.leftBarButtonItem = .backBarButton(self, selector: #selector(tokenInstanceViewControllerDidCloseSelected))

        return vc
    }

    @objc private func tokenInstanceViewControllerDidCloseSelected(_ sender: UIBarButtonItem) {
        navigationController.popViewController(animated: true)
    }

}

extension TokensCardCollectionCoordinator: TokensCardViewControllerDelegate {

    func didCancel(in viewController: TokensCardViewController) {
        delegate?.didClose(in: self)
    }

    private func showTokenInstanceActionView(forAction action: TokenInstanceAction, tokenHolder: TokenHolder, viewController: UIViewController) {
        delegate?.didTap(for: .send(type: .tokenScript(action: action, tokenObject: token, tokenHolder: tokenHolder)), in: self, viewController: viewController)
    }

    func didSelectTokenHolder(in viewController: TokensCardViewController, didSelectTokenHolder tokenHolder: TokenHolder) {
        switch tokenHolder.type {
        case .collectible:
            let viewModel = TokenCardListViewControllerViewModel(tokenHolder: tokenHolder)
            let viewController = TokenCardListViewController(viewModel: viewModel, tokenObject: token, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator, server: session.server)
            viewController.delegate = self

            navigationController.pushViewController(viewController, animated: true)
        case .single:
            showTokenInstance(tokenHolder: tokenHolder)
        }
    }

    func didTap(transaction: TransactionInstance, in viewController: TokensCardViewController) {
        delegate?.didTap(transaction: transaction, in: self)
    }

    func didTap(activity: Activity, in viewController: TokensCardViewController) {
        delegate?.didTap(activity: activity, in: self)
    }

    func didSelectAssetSelection(in viewController: TokensCardViewController) {
        showTokenCardSelection(tokenHolders: viewController.viewModel.tokenHolders)
    }

    private func showTokenCardSelection(tokenHolders: [TokenHolder]) {
        let coordinator = TokenCardSelectionCoordinator(navigationController: navigationController, tokenObject: token, tokenHolders: tokenHolders, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator, server: session.server)
        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start()
    }

    func showTokenInstance(tokenHolder: TokenHolder, mode: TokenInstanceViewMode = .interactive) {
        let viewController = makeTokenInstanceViewController(tokenHolder: tokenHolder, tokenId: tokenHolder.tokenId, mode: mode)
        viewController.navigationItem.leftBarButtonItem = .backBarButton(self, selector: #selector(didCloseTokenInstanceSelected))
        navigationController.pushViewController(viewController, animated: true)
    }

    @objc private func didCloseTokenInstanceSelected(_ sender: UIBarButtonItem) {
        navigationController.popViewController(animated: true)
    }

    private func showViewRedemptionInfo(in viewController: UIViewController) {
        let controller = TokenCardRedemptionInfoViewController(delegate: self)
        controller.navigationItem.largeTitleDisplayMode = .never

        viewController.navigationController?.pushViewController(controller, animated: true)
    }
}

extension TokensCardCollectionCoordinator: TokenCardRedemptionViewControllerDelegate {
}

extension TokensCardCollectionCoordinator: StaticHTMLViewControllerDelegate {
}

extension TokensCardCollectionCoordinator: TokenCardListViewControllerDelegate {
    func selectTokenCardsSelected(in viewController: TokenCardListViewController) {
        showTokenCardSelection(tokenHolders: [viewController.tokenHolder])
    }

    func didSelectTokenCard(in viewController: TokenCardListViewController, tokenId: TokenId) {
        let viewController = makeTokenInstanceViewController(tokenHolder: viewController.tokenHolder, tokenId: tokenId, mode: .interactive)
        navigationController.pushViewController(viewController, animated: true)
    }
}

extension TokensCardCollectionCoordinator: TokenCardSelectionCoordinatorDelegate {

    func didTapSend(in coordinator: TokenCardSelectionCoordinator, tokenObject: TokenObject, tokenHolders: [TokenHolder]) {
        removeCoordinator(coordinator)

        let filteredTokenHolders = tokenHolders.filter { $0.totalSelectedCount > 0 }
        guard let vc = navigationController.visibleViewController else { return }
        let transactionType: TransactionType = .erc1155Token(tokenObject, transferType: .singleTransfer, tokenHolders: filteredTokenHolders)
        delegate?.didTap(for: .send(type: .transaction(transactionType)), in: self, viewController: vc)
    }

    func didFinish(in coordinator: TokenCardSelectionCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension TokensCardCollectionCoordinator: TokenInstanceViewControllerDelegate {
    func didPressViewRedemptionInfo(in viewController: TokenInstanceViewController) {
        showViewRedemptionInfo(in: viewController)
    }

    func didPressRedeem(token: TokenObject, tokenHolder: TokenHolder, in viewController: TokenInstanceViewController) {
        //no-op
    }

    func didPressSell(tokenHolder: TokenHolder, for paymentFlow: PaymentFlow, in viewController: TokenInstanceViewController) {
        //no-op
    }

    func didPressTransfer(token: TokenObject, tokenHolder: TokenHolder, forPaymentFlow paymentFlow: PaymentFlow, in viewController: TokenInstanceViewController) {
        let transactionType: TransactionType = .erc1155Token(token, transferType: .singleTransfer, tokenHolders: [tokenHolder])
        delegate?.didTap(for: .send(type: .transaction(transactionType)), in: self, viewController: viewController)
    }

    func didTapURL(url: URL, in viewController: TokenInstanceViewController) {
        let controller = SFSafariViewController(url: url)
        // Don't attempt to change tint colors for SFSafariViewController. It doesn't well correctly especially because the controller sets more than 1 color for the title
        controller.makePresentationFullScreenForiOS13Migration()
        viewController.present(controller, animated: true)
    }

    func didTap(action: TokenInstanceAction, tokenHolder: TokenHolder, viewController: TokenInstanceViewController) {
        showTokenInstanceActionView(forAction: action, tokenHolder: tokenHolder, viewController: viewController)
    }
}

extension TokensCardCollectionCoordinator: CanOpenURL {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }
}

extension Collection where Element == TokenHolder {
    var valuesAll: [TokenId: [AttributeId: AssetAttributeSyntaxValue]] {
        var valuesAll: [TokenId: [AttributeId: AssetAttributeSyntaxValue]] = [:]
        for each in self {
            valuesAll.merge(each.valuesAll) { (current, _) in current }
        }
        return valuesAll
    }
}

extension Collection where Element == UnconfirmedTransaction.TokenIdAndValue {
    var erc1155TokenTransactionType: Erc1155TokenTransactionType {
        return count > 1 ? .batchTransfer : .singleTransfer
    }
}
