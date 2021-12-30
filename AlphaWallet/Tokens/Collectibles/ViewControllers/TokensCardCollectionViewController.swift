//
//  TokensCardCollectionViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 16.08.2021.
//

import Foundation
import UIKit
import BigInt
import PromiseKit
import RealmSwift

protocol TokensCardCollectionViewControllerDelegate: class, CanOpenURL {
    func didTap(transaction: TransactionInstance, in viewController: TokensCardCollectionViewController)
    func didTap(activity: Activity, in viewController: TokensCardCollectionViewController)
    func didSelectAssetSelection(in viewController: TokensCardCollectionViewController)
    func didSelectTokenHolder(in viewController: TokensCardCollectionViewController, didSelectTokenHolder tokenHolder: TokenHolder)
}

class TokensCardCollectionViewController: UIViewController {
    private (set) var viewModel: TokensCardCollectionViewControllerViewModel
    private let tokenObject: TokenObject
    private let session: WalletSession
    private let tokensDataStore: TokensDataStore
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: EventsDataStoreProtocol
    private let analyticsCoordinator: AnalyticsCoordinator
    private let buttonsBar = ButtonsBar(configuration: .combined(buttons: 2))
    private let tokenScriptFileStatusHandler: XMLHandler
    weak var delegate: TokensCardCollectionViewControllerDelegate?

    private let tokensCardCollectionInfoPageView: TokensCardCollectionInfoPageView
    private var activitiesPageView: ActivitiesPageView
    private var assetsPageView: AssetsPageView

    private let activitiesService: ActivitiesServiceType
    private let containerView: PagesContainerView

    init(session: WalletSession, tokensDataStore: TokensDataStore, assetDefinition: AssetDefinitionStore, analyticsCoordinator: AnalyticsCoordinator, token: TokenObject, viewModel: TokensCardCollectionViewControllerViewModel, activitiesService: ActivitiesServiceType, eventsDataStore: EventsDataStoreProtocol) {
        self.tokenObject = token
        self.viewModel = viewModel
        self.session = session
        self.tokenScriptFileStatusHandler = XMLHandler(token: tokenObject, assetDefinitionStore: assetDefinition)
        self.tokensDataStore = tokensDataStore
        self.assetDefinitionStore = assetDefinition
        self.eventsDataStore = eventsDataStore
        self.analyticsCoordinator = analyticsCoordinator
        self.activitiesService = activitiesService
        self.activitiesPageView = ActivitiesPageView(viewModel: .init(activitiesViewModel: .init()), sessions: activitiesService.sessions)
        self.assetsPageView = AssetsPageView(tokenObject: tokenObject, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator, server: session.server, viewModel: .init(tokenHolders: viewModel.tokenHolders))

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar)
        tokensCardCollectionInfoPageView = TokensCardCollectionInfoPageView(viewModel: .init(server: session.server, token: tokenObject, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, forWallet: session.account))
        let pageWithFooter = PageViewWithFooter(pageView: tokensCardCollectionInfoPageView, footerBar: footerBar)
        containerView = PagesContainerView(pages: [pageWithFooter, assetsPageView, activitiesPageView])

        super.init(nibName: nil, bundle: nil)

        hidesBottomBarWhenPushed = true

        activitiesPageView.delegate = self
        assetsPageView.delegate = self
        containerView.delegate = self

        view.addSubview(containerView)

        NSLayoutConstraint.activate([containerView.anchorsConstraint(to: view)])

        navigationItem.largeTitleDisplayMode = .never

        activitiesService.subscribableViewModel.subscribe { [weak self] viewModel in
            guard let strongSelf = self, let viewModel = viewModel else { return }

            strongSelf.activitiesPageView.configure(viewModel: .init(activitiesViewModel: viewModel))
        }

        //TODO disabled until we support batch transfers. Selection doesn't work correctly too
        assetsPageView.rightBarButtonItem = UIBarButtonItem.selectBarButton(self, selector: #selector(assetSelectionSelected))
        switch session.account.type {
        case .real:
            assetsPageView.rightBarButtonItem?.isEnabled = true
        case .watch:
            assetsPageView.rightBarButtonItem?.isEnabled = false
        }
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure(viewModel: viewModel)
    }

    func configure(viewModel: TokensCardCollectionViewControllerViewModel) {
        self.viewModel = viewModel

        view.backgroundColor = viewModel.backgroundColor
        title = viewModel.navigationTitle
        updateNavigationRightBarButtons(tokenScriptFileStatusHandler: tokenScriptFileStatusHandler)

        tokensCardCollectionInfoPageView.configure(viewModel: .init(server: session.server, token: tokenObject, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, forWallet: session.account))
        assetsPageView.configure(viewModel: .init(tokenHolders: viewModel.tokenHolders))

        let actions = viewModel.actions
        buttonsBar.configure(.combined(buttons: viewModel.actions.count))
        buttonsBar.viewController = self

        for (action, button) in zip(actions, buttonsBar.buttons) {
            button.setTitle(action.name, for: .normal)
            button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
            switch session.account.type {
            case .real:
                if let selection = action.activeExcludingSelection(selectedTokenHolder: viewModel.tokenHolders[0], tokenId: viewModel.tokenHolders[0].tokenId, forWalletAddress: session.account.address, fungibleBalance: viewModel.fungibleBalance) {
                    if selection.denial == nil {
                        button.displayButton = false
                    }
                }
            case .watch:
                button.isEnabled = false
            }
        }
    }

    private func updateNavigationRightBarButtons(tokenScriptFileStatusHandler xmlHandler: XMLHandler) {
        let tokenScriptStatusPromise = xmlHandler.tokenScriptStatus
        if tokenScriptStatusPromise.isPending {
            let label: UIBarButtonItem = .init(title: R.string.localizable.tokenScriptVerifying(), style: .plain, target: nil, action: nil)
            tokensCardCollectionInfoPageView.rightBarButtonItem = label

            tokenScriptStatusPromise.done { [weak self] _ in
                self?.updateNavigationRightBarButtons(tokenScriptFileStatusHandler: xmlHandler)
            }.cauterize()
        }

        if let server = xmlHandler.server, let status = tokenScriptStatusPromise.value, server.matches(server: session.server) {
            switch status {
            case .type0NoTokenScript:
                tokensCardCollectionInfoPageView.rightBarButtonItem = nil
            case .type1GoodTokenScriptSignatureGoodOrOptional, .type2BadTokenScript:
                let button = createTokenScriptFileStatusButton(withStatus: status, urlOpener: self)
                tokensCardCollectionInfoPageView.rightBarButtonItem = UIBarButtonItem(customView: button)
            }
        } else {
            tokensCardCollectionInfoPageView.rightBarButtonItem = nil
        }
    }

    @objc private func actionButtonTapped(sender: UIButton) {
        let actions = viewModel.actions
        for (_, button) in zip(actions, buttonsBar.buttons) where button == sender {
            //TODO ?!
        }
    }
}

extension TokensCardCollectionViewController: PagesContainerViewDelegate {
    func containerView(_ containerView: PagesContainerView, didSelectPage index: Int) {
        navigationItem.rightBarButtonItem = containerView.pages[index].rightBarButtonItem
    }

    @objc private func assetSelectionSelected(_ sender: UIBarButtonItem) {
        delegate?.didSelectAssetSelection(in: self)
    }
}

extension TokensCardCollectionViewController: CanOpenURL2 {
    func open(url: URL) {
        delegate?.didPressOpenWebPage(url, in: self)
    }
}

extension TokensCardCollectionViewController: TokensCardCollectionInfoPageViewDelegate {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, in view: TokensCardCollectionInfoPageView) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: session.server, in: self)
    }
}

extension TokensCardCollectionViewController: ActivitiesPageViewDelegate {
    func didTap(activity: Activity, in view: ActivitiesPageView) {
        delegate?.didTap(activity: activity, in: self)
    }

    func didTap(transaction: TransactionInstance, in view: ActivitiesPageView) {
        delegate?.didTap(transaction: transaction, in: self)
    }
}

extension TokensCardCollectionViewController: AssetsPageViewDelegate {
    func assetsPageView(_ view: AssetsPageView, didSelectTokenHolder tokenHolder: TokenHolder) {
        delegate?.didSelectTokenHolder(in: self, didSelectTokenHolder: tokenHolder)
    }
}
