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
    func didPressTransfer(token: TokenObject, tokenHolder: TokenHolder, forPaymentFlow paymentFlow: PaymentFlow, in viewController: TokensCardCollectionViewController)
    func didTap(action: TokenInstanceAction, tokenHolder: TokenHolder, viewController: TokensCardCollectionViewController)
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
    private var selectedTokenHolder: TokenHolder? {
        let selectedTokenHolders = viewModel.tokenHolders.filter { $0.isSelected }
        return selectedTokenHolders.first
    }
    private let activitiesService: ActivitiesServiceType
    private let containerView: PagesContainerView
    private lazy var keyboardChecker: KeyboardChecker = {
        let buttonsBarHeight: CGFloat = UIApplication.shared.bottomSafeAreaHeight > 0 ? -UIApplication.shared.bottomSafeAreaHeight : 0
        return KeyboardChecker(self, resetHeightDefaultValue: 0, ignoreBottomSafeArea: true, buttonsBarHeight: buttonsBarHeight)
    }()
    private let refreshControl = UIRefreshControl()
    private let account: Wallet

    init(session: WalletSession, tokensDataStore: TokensDataStore, assetDefinition: AssetDefinitionStore, analyticsCoordinator: AnalyticsCoordinator, token: TokenObject, viewModel: TokensCardCollectionViewControllerViewModel, activitiesService: ActivitiesServiceType, eventsDataStore: EventsDataStoreProtocol) {
        self.tokenObject = token
        self.viewModel = viewModel
        self.session = session
        self.account = session.account
        self.tokenScriptFileStatusHandler = XMLHandler(token: tokenObject, assetDefinitionStore: assetDefinition)
        self.tokensDataStore = tokensDataStore
        self.assetDefinitionStore = assetDefinition
        self.eventsDataStore = eventsDataStore
        self.analyticsCoordinator = analyticsCoordinator
        self.activitiesService = activitiesService
        self.activitiesPageView = ActivitiesPageView(viewModel: .init(activitiesViewModel: .init()), sessions: activitiesService.sessions)
        self.assetsPageView = AssetsPageView(assetDefinitionStore: assetDefinitionStore, viewModel: .init(tokenHolders: viewModel.tokenHolders, selection: .list))

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar)
        tokensCardCollectionInfoPageView = TokensCardCollectionInfoPageView(viewModel: .init(server: session.server, token: tokenObject, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, forWallet: session.account))
        let pageWithFooter = PageViewWithFooter(pageView: tokensCardCollectionInfoPageView, footerBar: footerBar)
        containerView = PagesContainerView(pages: [pageWithFooter, assetsPageView, activitiesPageView], selectedIndex: viewModel.initiallySelectedTabIndex)

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
        assetsPageView.searchBar.delegate = self
        assetsPageView.collectionView.refreshControl = refreshControl
        keyboardChecker.constraints = containerView.bottomAnchorConstraints

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
        refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
    }

    @objc private func didPullToRefresh(_ sender: UIRefreshControl) {
        viewModel.invalidateTokenHolders()
        configure()
        sender.endRefreshing()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hideNavigationBarTopSeparatorLine()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //NOTE: Calling keyboardCheckers `viewWillAppear` in viewWillAppear brakes layout
        keyboardChecker.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        keyboardChecker.viewWillDisappear()
        showNavigationBarTopSeparatorLine()
    }

    func configure(viewModel value: TokensCardCollectionViewControllerViewModel? = .none) {
        if let viewModel = value {
            self.viewModel = viewModel
        }

        view.backgroundColor = viewModel.backgroundColor
        title = viewModel.navigationTitle
        updateNavigationRightBarButtons(tokenScriptFileStatusHandler: tokenScriptFileStatusHandler)

        tokensCardCollectionInfoPageView.configure(viewModel: .init(server: session.server, token: tokenObject, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, forWallet: session.account))
        assetsPageView.configure(viewModel: .init(tokenHolders: viewModel.tokenHolders, selection: .list))

        let actions = viewModel.actions
        buttonsBar.configure(.combined(buttons: viewModel.actions.count))
        buttonsBar.viewController = self

        func _configButton(action: TokenInstanceAction, button: BarButton) {
            if let selection = action.activeExcludingSelection(selectedTokenHolder: viewModel.tokenHolders[0], tokenId: viewModel.tokenHolders[0].tokenId, forWalletAddress: session.account.address, fungibleBalance: viewModel.fungibleBalance) {
                if selection.denial == nil {
                    button.displayButton = false
                }
            }
        }

        for (action, button) in zip(actions, buttonsBar.buttons) {
            button.setTitle(action.name, for: .normal)
            button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
            switch session.account.type {
            case .real:
                _configButton(action: action, button: button)
            case .watch:
                //TODO pass in Config instance instead
                if Config().development.shouldPretendIsRealWallet {
                    _configButton(action: action, button: button)
                } else {
                    button.isEnabled = false
                }
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
        for (action, button) in zip(actions, buttonsBar.buttons) where button == sender {
            handle(action: action)
            break
        }
    }

    private func handle(action: TokenInstanceAction) {
        guard viewModel.tokenHolders.count == 1 else { return }
        let tokenHolder = viewModel.tokenHolders[0]
        tokenHolder.select(with: .allFor(tokenId: tokenHolder.tokenId))

        switch action.type {
        case .nftRedeem, .nftSell, .erc20Send, .erc20Receive, .swap, .buy, .bridge:
            break
        case .nonFungibleTransfer:
            transfer(tokenHolder: tokenHolder)
        case .tokenScript:
            if let selection = action.activeExcludingSelection(selectedTokenHolders: [tokenHolder], forWalletAddress: account.address) {
                if let denialMessage = selection.denial {
                    UIAlertController.alert(
                            title: nil,
                            message: denialMessage,
                            alertButtonTitles: [R.string.localizable.oK()],
                            alertButtonStyles: [.default],
                            viewController: self,
                            completion: nil
                    )
                } else {
                    //no-op shouldn't have reached here since the button should be disabled. So just do nothing to be safe
                }
            } else {
                delegate?.didTap(action: action, tokenHolder: tokenHolder, viewController: self)
            }
        }
    }

    private func transfer(tokenHolder: TokenHolder) {
        let transactionType = TransactionType(nonFungibleToken: tokenObject, tokenHolders: [tokenHolder])
        let paymentFlow: PaymentFlow = .send(type: .transaction(transactionType))

        delegate?.didPressTransfer(token: tokenObject, tokenHolder: tokenHolder, forPaymentFlow: paymentFlow, in: self)
    }
}

extension TokensCardCollectionViewController: UISearchBarDelegate {

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        assetsPageView.viewModel.searchFilter = .keyword(searchText)
        assetsPageView.reload(animatingDifferences: true)
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
