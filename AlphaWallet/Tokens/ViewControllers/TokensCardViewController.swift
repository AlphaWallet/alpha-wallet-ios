//
//  TokensCardViewController.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/24/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import UIKit

protocol TokensCardViewControllerDelegate: class, CanOpenURL {
    func didSelectAssetSelection(in viewController: TokensCardViewController)
    func didTap(transaction: TransactionInstance, in viewController: TokensCardViewController)
    func didTap(activity: Activity, in viewController: TokensCardViewController)
    func didSelectTokenHolder(in viewController: TokensCardViewController, didSelectTokenHolder tokenHolder: TokenHolder)
    func didCancel(in viewController: TokensCardViewController)
}

class TokensCardViewController: UIViewController {
    static let anArbitraryRowHeightSoAutoSizingCellsWorkIniOS10 = CGFloat(100)

    private (set) var viewModel: TokensCardViewModel
    private let tokenObject: TokenObject
    private let session: WalletSession
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: NonActivityEventsDataStore
    private let analyticsCoordinator: AnalyticsCoordinator
    private lazy var buttonsBar: ButtonsBar = {
        let buttonsBar = ButtonsBar(configuration: .empty)
        buttonsBar.viewController = self

        return buttonsBar
    }()
    private let tokenScriptFileStatusHandler: XMLHandler

    weak var delegate: TokensCardViewControllerDelegate?

    private lazy var collectionInfoPageView: TokensCardCollectionInfoPageView = {
        let viewModel: TokensCardCollectionInfoPageViewModel = .init(server: session.server, token: tokenObject, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, forWallet: session.account)
        let view = TokensCardCollectionInfoPageView(viewModel: viewModel, session: session)
        view.delegate = self

        return view
    }()

    private lazy var activitiesPageView: ActivitiesPageView = {
        let viewModel: ActivityPageViewModel = .init(activitiesViewModel: .init())
        let view = ActivitiesPageView(analyticsCoordinator: analyticsCoordinator, keystore: keystore, wallet: account, viewModel: viewModel, sessions: activitiesService.sessions)
        view.delegate = self

        return view
    }()

    private lazy var assetsPageView: AssetsPageView = {
        let viewModel: AssetsPageViewModel = .init(tokenHolders: viewModel.tokenHolders, selection: .list)
        let view = AssetsPageView(assetDefinitionStore: assetDefinitionStore, viewModel: viewModel)
        view.delegate = self
        view.rightBarButtonItem = UIBarButtonItem.switchGridToListViewBarButton(
            selection: viewModel.selection.inverted,
            self,
            selector: #selector(assetSelectionSelected)
        )
        view.searchBar.delegate = self
        view.collectionView.refreshControl = refreshControl

        return view
    }()
    private let account: Wallet
    private let refreshControl = UIRefreshControl()
    private lazy var keyboardChecker: KeyboardChecker = {
        return KeyboardChecker(self, resetHeightDefaultValue: 0, ignoreBottomSafeArea: true)
    }()
    private let activitiesService: ActivitiesServiceType
    private let keystore: Keystore

    init(keystore: Keystore, session: WalletSession, assetDefinition: AssetDefinitionStore, analyticsCoordinator: AnalyticsCoordinator, token: TokenObject, viewModel: TokensCardViewModel, activitiesService: ActivitiesServiceType, eventsDataStore: NonActivityEventsDataStore) {
        self.tokenObject = token
        self.viewModel = viewModel
        self.session = session
        self.account = session.account
        self.tokenScriptFileStatusHandler = XMLHandler(token: tokenObject, assetDefinitionStore: assetDefinition)
        self.assetDefinitionStore = assetDefinition
        self.eventsDataStore = eventsDataStore
        self.analyticsCoordinator = analyticsCoordinator
        self.activitiesService = activitiesService
        self.keystore = keystore
        
        super.init(nibName: nil, bundle: nil)

        hidesBottomBarWhenPushed = true

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar)
        let pageWithFooter = PageViewWithFooter(pageView: collectionInfoPageView, footerBar: footerBar)
        let pages: [PageViewType] = [pageWithFooter, assetsPageView, activitiesPageView]

        let containerView = PagesContainerView(pages: pages, selectedIndex: viewModel.initiallySelectedTabIndex)
        containerView.delegate = self
        view.addSubview(containerView)
        NSLayoutConstraint.activate([containerView.anchorsConstraint(to: view)])

        navigationItem.largeTitleDisplayMode = .never

        activitiesService.subscribableViewModel.subscribe { [weak activitiesPageView] viewModel in
            guard let view = activitiesPageView, let viewModel = viewModel else { return }

            view.configure(viewModel: .init(activitiesViewModel: viewModel))
        }

        keyboardChecker.constraints = containerView.bottomAnchorConstraints
        configure(assetsPageView: assetsPageView, viewModel: viewModel)
    }

    private func configure(assetsPageView: AssetsPageView, viewModel: TokensCardViewModel) {
        switch viewModel.token.type {
        case .erc1155:
            //TODO disabled until we support batch transfers. Selection doesn't work correctly too
            assetsPageView.rightBarButtonItem = UIBarButtonItem.selectBarButton(self, selector: #selector(assetSelectionSelected))

            switch session.account.type {
            case .real:
                assetsPageView.rightBarButtonItem?.isEnabled = true
            case .watch:
                assetsPageView.rightBarButtonItem?.isEnabled = false
            }
        case .erc721, .erc721ForTickets:
            let selection = assetsPageView.viewModel.selection.inverted
            let buttonItem = UIBarButtonItem.switchGridToListViewBarButton(selection: selection, self, selector: #selector(assetsDisplayTypeSelected))

            assetsPageView.rightBarButtonItem = buttonItem
        case .erc20, .nativeCryptocurrency, .erc875:
            break
        }
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
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

    override func viewDidLoad() {
        super.viewDidLoad()

        configure(viewModel: viewModel)
        refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)

        collectionInfoPageView.viewDidLoad()
    }

    @objc private func didPullToRefresh(_ sender: UIRefreshControl) {
        viewModel.invalidateTokenHolders()
        configure()
        sender.endRefreshing()
    }

    func configure(viewModel value: TokensCardViewModel? = .none) {
        if let viewModel = value {
            self.viewModel = viewModel
        }

        view.backgroundColor = viewModel.backgroundColor
        title = viewModel.navigationTitle
        updateNavigationRightBarButtons(tokenScriptFileStatusHandler: tokenScriptFileStatusHandler)

        collectionInfoPageView.configure(viewModel: .init(server: session.server, token: tokenObject, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, forWallet: session.account))
        assetsPageView.configure(viewModel: .init(tokenHolders: viewModel.tokenHolders, selection: assetsPageView.viewModel.selection))

        if collectionInfoPageView.viewModel.openInUrl != nil {
            buttonsBar.configure(.secondary(buttons: 1))
            let button = buttonsBar.buttons[0]
            button.setTitle(R.string.localizable.openOnOpenSea(), for: .normal)
            button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        } else {
            buttonsBar.configure(.empty)
        }
    }

    private func updateNavigationRightBarButtons(tokenScriptFileStatusHandler xmlHandler: XMLHandler) {
        let tokenScriptStatusPromise = xmlHandler.tokenScriptStatus
        if tokenScriptStatusPromise.isPending {
            let label: UIBarButtonItem = .init(title: R.string.localizable.tokenScriptVerifying(), style: .plain, target: nil, action: nil)
            collectionInfoPageView.rightBarButtonItem = label

            tokenScriptStatusPromise.done { [weak self] _ in
                self?.updateNavigationRightBarButtons(tokenScriptFileStatusHandler: xmlHandler)
            }.cauterize()
        }

        if Features.isTokenScriptSignatureStatusEnabled {
            if let server = xmlHandler.server, let status = tokenScriptStatusPromise.value, server.matches(server: session.server) {
                switch status {
                case .type0NoTokenScript:
                    collectionInfoPageView.rightBarButtonItem = nil
                case .type1GoodTokenScriptSignatureGoodOrOptional, .type2BadTokenScript:
                    let button = createTokenScriptFileStatusButton(withStatus: status, urlOpener: self)
                    collectionInfoPageView.rightBarButtonItem = UIBarButtonItem(customView: button)
                }
            } else {
                collectionInfoPageView.rightBarButtonItem = nil
            }
        } else {
            //no-op
        }
    }

    @objc private func actionButtonTapped(sender: UIButton) {
        guard let url = collectionInfoPageView.viewModel.openInUrl else { return }
        delegate?.didPressOpenWebPage(url, in: self)
    }
}

extension TokensCardViewController: UISearchBarDelegate {

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        assetsPageView.viewModel.searchFilter = .keyword(searchText)
        assetsPageView.reload(animatingDifferences: true)
    }
}

extension TokensCardViewController: PagesContainerViewDelegate {
    func containerView(_ containerView: PagesContainerView, didSelectPage index: Int) {
        navigationItem.rightBarButtonItem = containerView.pages[index].rightBarButtonItem
    }

    @objc private func assetSelectionSelected(_ sender: UIBarButtonItem) {
        delegate?.didSelectAssetSelection(in: self)
    }

    @objc private func assetsDisplayTypeSelected(_ sender: UIBarButtonItem) {
        let selection = assetsPageView.viewModel.selection
        assetsPageView.configure(viewModel: .init(tokenHolders: viewModel.tokenHolders, selection: sender.selection ?? selection))
        sender.toggleSelection()
    }
}

extension TokensCardViewController: CanOpenURL2 {
    func open(url: URL) {
        delegate?.didPressOpenWebPage(url, in: self)
    }
}

extension TokensCardViewController: TokensCardCollectionInfoPageViewDelegate {

    func didPressOpenWebPage(_ url: URL, in view: TokensCardCollectionInfoPageView) {
        delegate?.didPressOpenWebPage(url, in: self)
    }

    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, in view: TokensCardCollectionInfoPageView) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: session.server, in: self)
    }
}

extension TokensCardViewController: ActivitiesPageViewDelegate {
    func didTap(activity: Activity, in view: ActivitiesPageView) {
        delegate?.didTap(activity: activity, in: self)
    }

    func didTap(transaction: TransactionInstance, in view: ActivitiesPageView) {
        delegate?.didTap(transaction: transaction, in: self)
    }
}

extension TokensCardViewController: AssetsPageViewDelegate {
    func assetsPageView(_ view: AssetsPageView, didSelectTokenHolder tokenHolder: TokenHolder) {
        delegate?.didSelectTokenHolder(in: self, didSelectTokenHolder: tokenHolder)
    }
}

