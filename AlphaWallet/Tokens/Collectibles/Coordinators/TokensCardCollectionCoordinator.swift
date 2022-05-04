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
    private (set) lazy var rootViewController: NFTCollectionViewController = {
        return makeTokensCardCollectionViewController()
    }()

    private let session: WalletSession
    private let tokensStorage: TokensDataStore
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: NonActivityEventsDataStore
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
        navigationController.navigationBar.isTranslucent = false
    }

    func start() {
        let viewModel = NFTCollectionViewModel(token: token, forWallet: session.account, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore)
        rootViewController.configure(viewModel: viewModel)
        navigationController.pushViewController(rootViewController, animated: true)
        refreshUponEthereumEventChanges()
    }

    private func refreshUponEthereumEventChanges() {
        eventsDataStore
            .recentEvents(forTokenContract: token.contractAddress)
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] _ in
                self?.refreshScreen()
            }).store(in: &cancelable)

        assetDefinitionStore.assetsSignatureOrBodyChange(for: token.contractAddress)
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] _ in
                self?.refreshScreen()
            }).store(in: &cancelable)
    }

    private func refreshScreen() {
        for each in navigationController.viewControllers {
            switch each {
            case let vc as NFTCollectionViewController:
                let viewModel = NFTCollectionViewModel(token: token, forWallet: session.account, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore)
                vc.configure(viewModel: viewModel)
            case let vc as NFTAssetViewController:
                let updatedTokenHolders = token.getTokenHolders(assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, forWallet: session.account)
                if let selection = vc.viewModel.isMatchingTokenHolder(fromTokenHolders: updatedTokenHolders) {
                    let viewModel: NFTAssetViewModel = .init(account: session.account, tokenId: selection.tokenId, token: token, tokenHolder: selection.tokenHolder, assetDefinitionStore: assetDefinitionStore)
                    vc.configure(viewModel: viewModel)
                }
            default:
                break
            }
        }
    } 

    private func makeTokensCardCollectionViewController() -> NFTCollectionViewController {
        let viewModel = NFTCollectionViewModel(token: token, forWallet: session.account, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore)
        let activitiesFilterStrategy: ActivitiesFilterStrategy = .operationTypes(operationTypes: [.erc1155TokenTransfer], contract: token.contractAddress)
        let activitiesService = self.activitiesService.copy(activitiesFilterStrategy: activitiesFilterStrategy, transactionsFilterStrategy: TransactionDataStore.functional.transactionsFilter(for: activitiesFilterStrategy, tokenObject: token))

        let controller = NFTCollectionViewController(keystore: keystore, session: session, assetDefinition: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator, viewModel: viewModel, activitiesService: activitiesService, eventsDataStore: eventsDataStore)
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

    private func showNFTAssetViewController(tokenHolder: TokenHolder, tokenId: TokenId, mode: TokenInstanceViewMode) -> NFTAssetViewController {
        let viewModel = NFTAssetViewModel(account: session.account, tokenId: tokenHolder.tokenId, token: token, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
        let vc = NFTAssetViewController(analyticsCoordinator: analyticsCoordinator, assetDefinitionStore: assetDefinitionStore, viewModel: viewModel, mode: .interactive)
        vc.delegate = self 
        vc.navigationItem.largeTitleDisplayMode = .never
        vc.navigationItem.leftBarButtonItem = .backBarButton(self, selector: #selector(tokenInstanceViewControllerDidCloseSelected))

        return vc
    }

    @objc private func tokenInstanceViewControllerDidCloseSelected(_ sender: UIBarButtonItem) {
        navigationController.popViewController(animated: true)
    }

}

extension TokensCardCollectionCoordinator: NFTCollectionViewControllerDelegate {

    func didCancel(in viewController: NFTCollectionViewController) {
        delegate?.didClose(in: self)
    }

    private func showTokenInstanceActionView(forAction action: TokenInstanceAction, tokenHolder: TokenHolder, viewController: UIViewController) {
        delegate?.didTap(for: .send(type: .tokenScript(action: action, tokenObject: token, tokenHolder: tokenHolder)), in: self, viewController: viewController)
    }

    func didSelectTokenHolder(in viewController: NFTCollectionViewController, didSelectTokenHolder tokenHolder: TokenHolder) {
        switch tokenHolder.type {
        case .collectible:
            let viewModel = NFTAssetListViewModel(tokenHolder: tokenHolder)
            let viewController = NFTAssetListViewController(viewModel: viewModel, tokenObject: token, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator, server: session.server)
            viewController.delegate = self

            navigationController.pushViewController(viewController, animated: true)
        case .single:
            showNFTAsset(tokenHolder: tokenHolder)
        }
    }

    func didTap(transaction: TransactionInstance, in viewController: NFTCollectionViewController) {
        delegate?.didTap(transaction: transaction, in: self)
    }

    func didTap(activity: Activity, in viewController: NFTCollectionViewController) {
        delegate?.didTap(activity: activity, in: self)
    }

    func didSelectAssetSelection(in viewController: NFTCollectionViewController) {
        showTokenCardSelection(tokenHolders: viewController.viewModel.tokenHolders)
    }

    private func showTokenCardSelection(tokenHolders: [TokenHolder]) {
        let coordinator = NFTAssetSelectionCoordinator(navigationController: navigationController, tokenObject: token, tokenHolders: tokenHolders, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator, server: session.server)
        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start()
    }

    func showNFTAsset(tokenHolder: TokenHolder, mode: TokenInstanceViewMode = .interactive) {
        let viewController = showNFTAssetViewController(tokenHolder: tokenHolder, tokenId: tokenHolder.tokenId, mode: mode)
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

extension TokensCardCollectionCoordinator: NFTAssetListViewControllerDelegate {
    func selectTokenCardsSelected(in viewController: NFTAssetListViewController) {
        showTokenCardSelection(tokenHolders: [viewController.tokenHolder])
    }

    func didSelectTokenCard(in viewController: NFTAssetListViewController, tokenId: TokenId) {
        let viewController = showNFTAssetViewController(tokenHolder: viewController.tokenHolder, tokenId: tokenId, mode: .interactive)
        navigationController.pushViewController(viewController, animated: true)
    }
}

extension TokensCardCollectionCoordinator: NFTAssetSelectionCoordinatorDelegate {

    func didTapSend(in coordinator: NFTAssetSelectionCoordinator, tokenObject: TokenObject, tokenHolders: [TokenHolder]) {
        removeCoordinator(coordinator)

        let filteredTokenHolders = tokenHolders.filter { $0.totalSelectedCount > 0 }
        guard let vc = navigationController.visibleViewController else { return }
        let transactionType: TransactionType = .erc1155Token(tokenObject, transferType: .singleTransfer, tokenHolders: filteredTokenHolders)
        delegate?.didTap(for: .send(type: .transaction(transactionType)), in: self, viewController: vc)
    }

    func didFinish(in coordinator: NFTAssetSelectionCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension TokensCardCollectionCoordinator: NonFungibleTokenViewControllerDelegate {
    func didPressViewRedemptionInfo(in viewController: NFTAssetViewController) {
        showViewRedemptionInfo(in: viewController)
    }

    func didPressRedeem(token: TokenObject, tokenHolder: TokenHolder, in viewController: NFTAssetViewController) {
        //no-op
    }

    func didPressSell(tokenHolder: TokenHolder, for paymentFlow: PaymentFlow, in viewController: NFTAssetViewController) {
        //no-op
    }

    func didPressTransfer(token: TokenObject, tokenHolder: TokenHolder, forPaymentFlow paymentFlow: PaymentFlow, in viewController: NFTAssetViewController) {
        let transactionType: TransactionType = .erc1155Token(token, transferType: .singleTransfer, tokenHolders: [tokenHolder])
        delegate?.didTap(for: .send(type: .transaction(transactionType)), in: self, viewController: viewController)
    }

    func didTapURL(url: URL, in viewController: NFTAssetViewController) {
        let controller = SFSafariViewController(url: url)
        // Don't attempt to change tint colors for SFSafariViewController. It doesn't well correctly especially because the controller sets more than 1 color for the title
        controller.makePresentationFullScreenForiOS13Migration()
        viewController.present(controller, animated: true)
    }

    func didTap(action: TokenInstanceAction, tokenHolder: TokenHolder, viewController: NFTAssetViewController) {
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
