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
    private let roundedBackground = RoundedBackground()
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
    var isReadOnly: Bool = false

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

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)
        roundedBackground.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: roundedBackground.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))

        navigationItem.largeTitleDisplayMode = .never

        activitiesService.subscribableViewModel.subscribe { [weak self] viewModel in
            guard let strongSelf = self, let viewModel = viewModel else { return }

            strongSelf.activitiesPageView.configure(viewModel: .init(activitiesViewModel: viewModel))
        }
        //TODO disabled until we support batch transfers. Selection doesn't work correctly too
        //assetsPageView.rightBarButtonItem = UIBarButtonItem(title: "Select", style: .plain, target: self, action: #selector(assetSelectionSelected))
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

        //FIXME: replace it
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

struct TokensCardCollectionViewControllerViewModel {

    var fungibleBalance: BigInt? {
        return nil
    }

    private let assetDefinitionStore: AssetDefinitionStore
    let token: TokenObject
    let tokenHolders: [TokenHolder]
    let actions: [TokenInstanceAction] = []

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var navigationTitle: String {
        return token.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
    }

    init(token: TokenObject, forWallet account: Wallet, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: EventsDataStoreProtocol) {
        self.token = token
        self.tokenHolders = TokenAdaptor(token: token, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore).getTokenHolders(forWallet: account)
        self.assetDefinitionStore = assetDefinitionStore
    }

    func tokenHolder(at indexPath: IndexPath) -> TokenHolder {
        return tokenHolders[indexPath.section]
    }

    func numberOfItems() -> Int {
        return tokenHolders.count
    }

}
