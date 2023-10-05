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
import AlphaWalletFoundation
import AlphaWalletTokenScript

protocol NFTCollectionViewControllerDelegate: AnyObject, CanOpenURL {
    func didSelectAssetSelection(in viewController: NFTCollectionViewController)
    func didTap(transaction: Transaction, in viewController: NFTCollectionViewController)
    func didTap(activity: Activity, in viewController: NFTCollectionViewController)
    func didSelectTokenHolder(in viewController: NFTCollectionViewController, didSelectTokenHolder tokenHolder: TokenHolder)
    func didClose(in viewController: NFTCollectionViewController)
}

class NFTCollectionViewController: UIViewController {
    private let session: WalletSession
    private let sessionsProvider: SessionsProvider
    private let assetDefinitionStore: AssetDefinitionStore
    private let analytics: AnalyticsLogger
    private lazy var buttonsBar: HorizontalButtonsBar = {
        let buttonsBar = HorizontalButtonsBar(configuration: .empty)
        buttonsBar.viewController = self

        return buttonsBar
    }()

    private lazy var collectionInfoPageView: NFTCollectionInfoPageView = {
        let view = NFTCollectionInfoPageView(viewModel: viewModel.infoPageViewModel, session: session, tokenCardViewFactory: tokenCardViewFactory)
        view.delegate = self

        return view
    }()

    private lazy var activitiesPageView: ActivitiesPageView = {
        let viewModel: ActivityPageViewModel = .init(activitiesViewModel: .init(collection: .init()))
        let view = ActivitiesPageView(analytics: analytics, keystore: keystore, wallet: self.viewModel.wallet, viewModel: viewModel, sessionsProvider: sessionsProvider, assetDefinitionStore: assetDefinitionStore, tokenImageFetcher: tokenImageFetcher)
        view.delegate = self

        return view
    }()
    private let willAppear = PassthroughSubject<Void, Never>()

    private lazy var nftAssetsPageView: NFTAssetsPageView = {
        let view = NFTAssetsPageView(tokenCardViewFactory: tokenCardViewFactory, viewModel: viewModel.nftAssetsPageViewModel)
        view.delegate = self
        view.searchBar.delegate = self
        view.collectionView.refreshControl = refreshControl

        return view
    }()
    private let refreshControl = UIRefreshControl()
    private lazy var keyboardChecker: KeyboardChecker = {
        return KeyboardChecker(self, resetHeightDefaultValue: 0, ignoreBottomSafeArea: true)
    }()
    private let keystore: Keystore
    private var cancellable = Set<AnyCancellable>()
    private let tokenCardViewFactory: TokenCardViewFactory
    private let tokenImageFetcher: TokenImageFetcher

    let viewModel: NFTCollectionViewModel
    weak var delegate: NFTCollectionViewControllerDelegate?

    init(keystore: Keystore,
         session: WalletSession,
         assetDefinition: AssetDefinitionStore,
         analytics: AnalyticsLogger,
         viewModel: NFTCollectionViewModel,
         sessionsProvider: SessionsProvider,
         tokenCardViewFactory: TokenCardViewFactory,
         tokenImageFetcher: TokenImageFetcher) {

        self.tokenImageFetcher = tokenImageFetcher
        self.tokenCardViewFactory = tokenCardViewFactory
        self.viewModel = viewModel
        self.sessionsProvider = sessionsProvider
        self.session = session
        self.assetDefinitionStore = assetDefinition
        self.analytics = analytics
        self.keystore = keystore

        super.init(nibName: nil, bundle: nil)

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar)
        let pageWithFooter = PageViewWithFooter(pageView: collectionInfoPageView, footerBar: footerBar)
        let pages: [PageViewType] = [pageWithFooter, nftAssetsPageView, activitiesPageView]

        let containerView = PagesContainerView(pages: pages, selectedIndex: viewModel.initiallySelectedTabIndex)
        containerView.delegate = self
        view.addSubview(containerView)
        NSLayoutConstraint.activate([containerView.anchorsConstraint(to: view)])

        keyboardChecker.constraints = containerView.bottomAnchorConstraints
        navigationItem.largeTitleDisplayMode = .never
        hidesBottomBarWhenPushed = true

        configure(nftAssetsPageView: nftAssetsPageView, viewModel: viewModel)
    }

    private func configure(nftAssetsPageView: NFTAssetsPageView, viewModel: NFTCollectionViewModel) {
        switch viewModel.rightBarButtonItem {
        case .none:
            nftAssetsPageView.rightBarButtonItem = .none
        case .assetSelection(let isEnabled):
            nftAssetsPageView.rightBarButtonItem = UIBarButtonItem.selectBarButton(self, selector: #selector(assetSelectionSelected))
            nftAssetsPageView.rightBarButtonItem?.isEnabled = isEnabled
        case .assetsDisplayType(let layout):
            let buttonItem = UIBarButtonItem.switchGridToListViewBarButton(gridOrListLayout: layout, self, selector: #selector(assetsDisplayTypeSelected))

            nftAssetsPageView.rightBarButtonItem = buttonItem
        }
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    deinit {
        nftAssetsPageView.resetStatefulStateToReleaseObjectToAvoidMemoryLeak()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        hideNavigationBarTopSeparatorLine()
        nftAssetsPageView.viewWillAppear()
        willAppear.send(())
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

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        bind(viewModel: viewModel)
    }

    private func bind(viewModel: NFTCollectionViewModel) {
        updateNavigationRightBarButtons(tokenScriptFileStatusHandler: viewModel.tokenScriptFileStatusHandler)

        let input = NFTCollectionViewModelInput(
            willAppear: willAppear.eraseToAnyPublisher(),
            pullToRefresh: refreshControl.publisher(forEvent: .valueChanged).eraseToAnyPublisher())

        let output = viewModel.transform(input: input)

        output.viewState
            .sink { [weak self] state in
                self?.title = state.title
                self?.buildBarButtons(from: state.actions)
            }.store(in: &cancellable)

        output.activities
            .sink { [weak activitiesPageView] in activitiesPageView?.configure(viewModel: $0) }
            .store(in: &cancellable)

        output.pullToRefreshState
            .sink { [refreshControl] state in
                switch state {
                case .done, .failure: refreshControl.endRefreshing()
                case .loading: refreshControl.beginRefreshing()
                }
            }.store(in: &cancellable)
    }

    //NOTE: there is only one possible action for now
    private func buildBarButtons(from actions: [NFTCollectionViewModel.NonFungibleTokenAction]) {
        buttonsBar.cancellable.cancellAll()
        if actions.isEmpty {
            buttonsBar.configure(.empty)
        } else {
            buttonsBar.configure(.secondary(buttons: actions.count))
            for (index, each) in actions.enumerated() {
                let button = buttonsBar.buttons[index]
                button.setTitle(each.name, for: .normal)
                button.publisher(forEvent: .touchUpInside)
                    .sink { [weak self] _ in self?.perform(action: each) }
                    .store(in: &buttonsBar.cancellable)
            }
        }
    }

    private func updateNavigationRightBarButtons(tokenScriptFileStatusHandler xmlHandler: XMLHandler) {
        if Features.current.isAvailable(.isTokenScriptSignatureStatusEnabled) {
            let tokenScriptStatusPromise = xmlHandler.tokenScriptStatus
            if tokenScriptStatusPromise.isPending {
                let label: UIBarButtonItem = .init(title: R.string.localizable.tokenScriptVerifying(), style: .plain, target: nil, action: nil)
                collectionInfoPageView.rightBarButtonItem = label

                tokenScriptStatusPromise.done { [weak self] _ in
                    self?.updateNavigationRightBarButtons(tokenScriptFileStatusHandler: xmlHandler)
                }.cauterize()
            }

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

    private func perform(action: NFTCollectionViewModel.NonFungibleTokenAction) {
        switch action {
        case .openInUrl(let url):
            delegate?.didPressOpenWebPage(url, in: self)
        }
    }
}

extension NFTCollectionViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        delegate?.didClose(in: self)
    }
}

extension NFTCollectionViewController: UISearchBarDelegate {

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        nftAssetsPageView.viewModel.set(searchFilter: .keyword(searchText))
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
        nftAssetsPageView.viewModel.set(layout: sender.gridOrListLayout ?? nftAssetsPageView.viewModel.layout)
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

    func didTap(transaction: Transaction, in view: ActivitiesPageView) {
        delegate?.didTap(transaction: transaction, in: self)
    }
}

extension NFTCollectionViewController: NFTAssetsPageViewDelegate {
    func nftAssetsPageView(_ view: NFTAssetsPageView, didSelectTokenHolder tokenHolder: TokenHolder) {
        delegate?.didSelectTokenHolder(in: self, didSelectTokenHolder: tokenHolder)
    }
}
