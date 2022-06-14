//
//  NFTCollectionViewController.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/24/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import UIKit
import Combine

protocol NFTCollectionViewControllerDelegate: class, CanOpenURL {
    func didSelectAssetSelection(in viewController: NFTCollectionViewController)
    func didTap(transaction: TransactionInstance, in viewController: NFTCollectionViewController)
    func didTap(activity: Activity, in viewController: NFTCollectionViewController)
    func didSelectTokenHolder(in viewController: NFTCollectionViewController, didSelectTokenHolder tokenHolder: TokenHolder)
    func didCancel(in viewController: NFTCollectionViewController)
}

class NFTCollectionViewController: UIViewController {
    private (set) var viewModel: NFTCollectionViewModel
    private let openSea: OpenSea
    private let session: WalletSession
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: NonActivityEventsDataStore
    private let analyticsCoordinator: AnalyticsCoordinator
    private lazy var buttonsBar: HorizontalButtonsBar = {
        let buttonsBar = HorizontalButtonsBar(configuration: .empty)
        buttonsBar.viewController = self

        return buttonsBar
    }()

    private let tokenScriptFileStatusHandler: XMLHandler

    private lazy var collectionInfoPageView: NFTCollectionInfoPageView = {
        let viewModel: NFTCollectionInfoPageViewModel = .init(token: viewModel.token, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, wallet: session.account)
        let view = NFTCollectionInfoPageView(viewModel: viewModel, openSea: openSea, keystore: keystore, session: session, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator)
        view.delegate = self

        return view
    }()

    private lazy var activitiesPageView: ActivitiesPageView = {
        let viewModel: ActivityPageViewModel = .init(activitiesViewModel: .init())
        let view = ActivitiesPageView(analyticsCoordinator: analyticsCoordinator, keystore: keystore, wallet: session.account, viewModel: viewModel, sessions: activitiesService.sessions, assetDefinitionStore: assetDefinitionStore)
        view.delegate = self

        return view
    }()

    private lazy var nftAssetsPageView: NFTAssetsPageView = {
        let tokenCardViewFactory = TokenCardViewFactory(token: viewModel.token, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator, keystore: keystore, wallet: viewModel.wallet)
        let viewModel: NFTAssetsPageViewModel = .init(token: viewModel.token, assetDefinitionStore: assetDefinitionStore, tokenHolders: viewModel.tokenHolders, selection: .list)

        let view = NFTAssetsPageView(tokenCardViewFactory: tokenCardViewFactory, viewModel: viewModel)
        view.delegate = self
        view.searchBar.delegate = self
        view.collectionView.refreshControl = refreshControl

        return view
    }()
    private let refreshControl = UIRefreshControl()
    private lazy var keyboardChecker: KeyboardChecker = {
        return KeyboardChecker(self, resetHeightDefaultValue: 0, ignoreBottomSafeArea: true)
    }()
    private let activitiesService: ActivitiesServiceType
    private let keystore: Keystore
    private var cancelable = Set<AnyCancellable>()

    weak var delegate: NFTCollectionViewControllerDelegate?

    init(keystore: Keystore, session: WalletSession, assetDefinition: AssetDefinitionStore, analyticsCoordinator: AnalyticsCoordinator, viewModel: NFTCollectionViewModel, openSea: OpenSea, activitiesService: ActivitiesServiceType, eventsDataStore: NonActivityEventsDataStore) {
        self.viewModel = viewModel
        self.openSea = openSea
        self.session = session
        self.tokenScriptFileStatusHandler = XMLHandler(token: viewModel.token, assetDefinitionStore: assetDefinition)
        self.assetDefinitionStore = assetDefinition
        self.eventsDataStore = eventsDataStore
        self.analyticsCoordinator = analyticsCoordinator
        self.activitiesService = activitiesService
        self.keystore = keystore

        super.init(nibName: nil, bundle: nil)

        hidesBottomBarWhenPushed = true

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar)
        let pageWithFooter = PageViewWithFooter(pageView: collectionInfoPageView, footerBar: footerBar)
        let pages: [PageViewType] = [pageWithFooter, nftAssetsPageView, activitiesPageView]

        let containerView = PagesContainerView(pages: pages, selectedIndex: viewModel.initiallySelectedTabIndex)
        containerView.delegate = self
        view.addSubview(containerView)
        NSLayoutConstraint.activate([containerView.anchorsConstraint(to: view)])

        navigationItem.largeTitleDisplayMode = .never

        keyboardChecker.constraints = containerView.bottomAnchorConstraints
        configure(nftAssetsPageView: nftAssetsPageView, viewModel: viewModel)
    }

    private func configure(nftAssetsPageView: NFTAssetsPageView, viewModel: NFTCollectionViewModel) {
        switch viewModel.token.type {
        case .erc1155:
            nftAssetsPageView.rightBarButtonItem = UIBarButtonItem.selectBarButton(self, selector: #selector(assetSelectionSelected))

            switch session.account.type {
            case .real:
                nftAssetsPageView.rightBarButtonItem?.isEnabled = true
            case .watch:
                nftAssetsPageView.rightBarButtonItem?.isEnabled = Config().development.shouldPretendIsRealWallet
            }
        case .erc721, .erc721ForTickets, .erc875:
            let selection = nftAssetsPageView.viewModel.selection.inverted
            let buttonItem = UIBarButtonItem.switchGridToListViewBarButton(selection: selection, self, selector: #selector(assetsDisplayTypeSelected))

            nftAssetsPageView.rightBarButtonItem = buttonItem
        case .erc20, .nativeCryptocurrency:
            nftAssetsPageView.rightBarButtonItem = .none
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

        activitiesService.activitiesPublisher
            .receive(on: RunLoop.main)
            .sink { [weak activitiesPageView] activities in
                activitiesPageView?.configure(viewModel: .init(activitiesViewModel: .init(activities: activities)))
            }.store(in: &cancelable)
    }

    @objc private func didPullToRefresh(_ sender: UIRefreshControl) {
        viewModel.invalidateTokenHolders()
        configure()
        sender.endRefreshing()
    }

    func configure(viewModel value: NFTCollectionViewModel? = .none) {
        if let viewModel = value {
            self.viewModel = viewModel
        }

        view.backgroundColor = viewModel.backgroundColor
        title = viewModel.navigationTitle
        updateNavigationRightBarButtons(tokenScriptFileStatusHandler: tokenScriptFileStatusHandler)

        collectionInfoPageView.configure(viewModel: .init(token: viewModel.token, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, wallet: session.account))
        nftAssetsPageView.configure(viewModel: .init(token: viewModel.token, assetDefinitionStore: assetDefinitionStore, tokenHolders: viewModel.tokenHolders, selection: nftAssetsPageView.viewModel.selection))

        if viewModel.openInUrl != nil {
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

        if Features.default.isAvailable(.isTokenScriptSignatureStatusEnabled) {
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
        guard let url = viewModel.openInUrl else { return }
        delegate?.didPressOpenWebPage(url, in: self)
    }
}

extension NFTCollectionViewController: UISearchBarDelegate {

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        nftAssetsPageView.viewModel.searchFilter = .keyword(searchText)
        nftAssetsPageView.reload(animatingDifferences: true)
    }
}

extension NFTCollectionViewController: PagesContainerViewDelegate {
    func containerView(_ containerView: PagesContainerView, didSelectPage index: Int) {
        navigationItem.rightBarButtonItem = containerView.pages[index].rightBarButtonItem
    }

    @objc private func assetSelectionSelected(_ sender: UIBarButtonItem) {
        delegate?.didSelectAssetSelection(in: self)
    }

    @objc private func assetsDisplayTypeSelected(_ sender: UIBarButtonItem) {
        let selection = nftAssetsPageView.viewModel.selection
        nftAssetsPageView.configure(viewModel: .init(token: viewModel.token, assetDefinitionStore: assetDefinitionStore, tokenHolders: viewModel.tokenHolders, selection: sender.selection ?? selection))
        sender.toggleSelection()
    }
}

extension NFTCollectionViewController: CanOpenURL2 {
    func open(url: URL) {
        delegate?.didPressOpenWebPage(url, in: self)
    }
}

extension NFTCollectionViewController: NFTCollectionInfoPageViewDelegate {

    func didPressOpenWebPage(_ url: URL, in view: NFTCollectionInfoPageView) {
        delegate?.didPressOpenWebPage(url, in: self)
    }

    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, in view: NFTCollectionInfoPageView) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: session.server, in: self)
    }
}

extension NFTCollectionViewController: ActivitiesPageViewDelegate {
    func didTap(activity: Activity, in view: ActivitiesPageView) {
        delegate?.didTap(activity: activity, in: self)
    }

    func didTap(transaction: TransactionInstance, in view: ActivitiesPageView) {
        delegate?.didTap(transaction: transaction, in: self)
    }
}

extension NFTCollectionViewController: NFTAssetsPageViewDelegate {
    func nftAssetsPageView(_ view: NFTAssetsPageView, didSelectTokenHolder tokenHolder: TokenHolder) {
        delegate?.didSelectTokenHolder(in: self, didSelectTokenHolder: tokenHolder)
    }
}

