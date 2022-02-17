//
//  TokensCardViewController.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/24/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import UIKit
import Result

protocol TokensCardViewControllerDelegate: class, CanOpenURL {
    func didTap(transaction: TransactionInstance, in viewController: TokensCardViewController)
    func didTap(activity: Activity, in viewController: TokensCardViewController)
    func didSelectTokenHolder(in viewController: TokensCardViewController, didSelectTokenHolder tokenHolder: TokenHolder)
    func didPressRedeem(token: TokenObject, tokenHolder: TokenHolder, in viewController: TokensCardViewController)
    func didPressSell(tokenHolder: TokenHolder, for paymentFlow: PaymentFlow, in viewController: TokensCardViewController)
    func didPressTransfer(token: TokenObject, tokenHolder: TokenHolder, for type: PaymentFlow, in viewController: TokensCardViewController)
    func didCancel(in viewController: TokensCardViewController)
    func didPressViewRedemptionInfo(in viewController: TokensCardViewController)
    func didTapURL(url: URL, in viewController: TokensCardViewController)
    func didTapTokenInstanceIconified(tokenHolder: TokenHolder, in viewController: TokensCardViewController)
    func didTap(action: TokenInstanceAction, tokenHolder: TokenHolder, viewController: TokensCardViewController)
}

class TokensCardViewController: UIViewController {
    static let anArbitraryRowHeightSoAutoSizingCellsWorkIniOS10 = CGFloat(100)

    private (set) var viewModel: TokensCardViewModel
    private let tokenObject: TokenObject
    private let session: WalletSession
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: EventsDataStoreProtocol
    private let analyticsCoordinator: AnalyticsCoordinator
    private let buttonsBar = ButtonsBar(configuration: .combined(buttons: 2))
    private let tokenScriptFileStatusHandler: XMLHandler
    weak var delegate: TokensCardViewControllerDelegate?

    private let tokensCardCollectionInfoPageView: TokensCardCollectionInfoPageView
    private var activitiesPageView: ActivitiesPageView
    private var assetsPageView: AssetsPageView
    private let containerView: PagesContainerView

    private var selectedTokenHolder: TokenHolder? {
        let selectedTokenHolders = viewModel.tokenHolders.filter { $0.isSelected }
        return selectedTokenHolders.first
    }

    private let account: Wallet
    private let refreshControl = UIRefreshControl()
    private lazy var keyboardChecker: KeyboardChecker = {
        let buttonsBarHeight: CGFloat = UIApplication.shared.bottomSafeAreaHeight > 0 ? -UIApplication.shared.bottomSafeAreaHeight : 0
        return KeyboardChecker(self, resetHeightDefaultValue: 0, ignoreBottomSafeArea: true, buttonsBarHeight: buttonsBarHeight)
    }()

    init(session: WalletSession, assetDefinition: AssetDefinitionStore, analyticsCoordinator: AnalyticsCoordinator, token: TokenObject, viewModel: TokensCardViewModel, activitiesService: ActivitiesServiceType, eventsDataStore: EventsDataStoreProtocol) {
        self.tokenObject = token
        self.viewModel = viewModel
        self.session = session
        self.account = session.account
        self.tokenScriptFileStatusHandler = XMLHandler(token: tokenObject, assetDefinitionStore: assetDefinition)
        self.assetDefinitionStore = assetDefinition
        self.eventsDataStore = eventsDataStore
        self.analyticsCoordinator = analyticsCoordinator
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

        activitiesService.subscribableViewModel.subscribe { [weak activitiesPageView] viewModel in
            guard let view = activitiesPageView, let viewModel = viewModel else { return }

            view.configure(viewModel: .init(activitiesViewModel: viewModel))
        }
        assetsPageView.rightBarButtonItem = UIBarButtonItem.switchGridToListViewBarButton(
            selection: assetsPageView.viewModel.selection.inverted,
            self,
            selector: #selector(assetSelectionSelected)
        )
        assetsPageView.searchBar.delegate = self
        assetsPageView.collectionView.refreshControl = refreshControl
        keyboardChecker.constraints = containerView.bottomAnchorConstraints
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

        tokensCardCollectionInfoPageView.configure(viewModel: .init(server: session.server, token: tokenObject, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, forWallet: session.account))
        assetsPageView.configure(viewModel: .init(tokenHolders: viewModel.tokenHolders, selection: assetsPageView.viewModel.selection))

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
                //TODO pass in a Config instance instead
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
        viewModel.markHolderSelected()

        guard let tokenHolder = selectedTokenHolder else { return }

        switch action.type {
        case .erc20Send, .erc20Receive, .swap, .buy, .bridge:
            break
        case .nftRedeem:
            redeem()
        case .nftSell:
            sell()
        case .nonFungibleTransfer:
            transfer()
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

    func redeem() {
        guard let selectedTokenHolder = selectedTokenHolder else { return }
        delegate?.didPressRedeem(token: viewModel.token, tokenHolder: selectedTokenHolder, in: self)
    }

    func sell() {
        guard let selectedTokenHolder = selectedTokenHolder else { return }
        let transactionType = TransactionType.erc875Token(viewModel.token, tokenHolders: [selectedTokenHolder])
        delegate?.didPressSell(tokenHolder: selectedTokenHolder, for: .send(type: .transaction(transactionType)), in: self)
    }

    func transfer() {
        guard let selectedTokenHolder = selectedTokenHolder else { return }
        let transactionType = TransactionType(nonFungibleToken: viewModel.token, tokenHolders: [selectedTokenHolder])
        delegate?.didPressTransfer(token: viewModel.token, tokenHolder: selectedTokenHolder, for: .send(type: .transaction(transactionType)), in: self)
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

