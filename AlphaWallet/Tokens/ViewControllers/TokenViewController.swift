// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt
import PromiseKit
import RealmSwift

protocol TokenViewControllerDelegate: class, CanOpenURL {
    func didTapSwap(forTransactionType transactionType: TransactionType, service: SwapTokenURLProviderType, inViewController viewController: TokenViewController)
    func shouldOpen(url: URL, shouldSwitchServer: Bool, forTransactionType transactionType: TransactionType, inViewController viewController: TokenViewController)
    func didTapSend(forTransactionType transactionType: TransactionType, inViewController viewController: TokenViewController)
    func didTapReceive(forTransactionType transactionType: TransactionType, inViewController viewController: TokenViewController)
    func didTap(transaction: TransactionInstance, inViewController viewController: TokenViewController)
    func didTap(activity: Activity, inViewController viewController: TokenViewController)
    func didTap(action: TokenInstanceAction, transactionType: TransactionType, viewController: TokenViewController)
    func didTapAddAlert(for tokenObject: TokenObject, in viewController: TokenViewController)
    func didTapEditAlert(for tokenObject: TokenObject, alert: PriceAlert, in viewController: TokenViewController)
}

class TokenViewController: UIViewController {
    private var viewModel: TokenViewControllerViewModel
    private var tokenHolder: TokenHolder?
    private let tokenObject: TokenObject
    private let session: WalletSession
    private let assetDefinitionStore: AssetDefinitionStore
    private let transactionType: TransactionType
    private let analyticsCoordinator: AnalyticsCoordinator
    private let buttonsBar = ButtonsBar(configuration: .combined(buttons: 2))
    private lazy var tokenScriptFileStatusHandler = XMLHandler(token: tokenObject, assetDefinitionStore: assetDefinitionStore)
    weak var delegate: TokenViewControllerDelegate?

    private lazy var tokenInfoPageView: TokenInfoPageView = {
        let view = TokenInfoPageView(server: session.server, token: tokenObject, config: session.config, transactionType: transactionType)
        view.delegate = self

        return view
    }()
    private var activitiesPageView: ActivitiesPageView
    private var alertsPageView: PriceAlertsPageView
    private let activitiesService: ActivitiesServiceType
    private var activitiesSubscriptionKey: Subscribable<ActivitiesViewModel>.SubscribableKey?
    private var alertsSubscriptionKey: Subscribable<[PriceAlert]>.SubscribableKey?
    private let alertService: PriceAlertServiceType
    private lazy var alertsSubscribable = alertService.alertsSubscribable(strategy: .token(tokenObject))

    init(session: WalletSession, assetDefinition: AssetDefinitionStore, transactionType: TransactionType, analyticsCoordinator: AnalyticsCoordinator, token: TokenObject, viewModel: TokenViewControllerViewModel, activitiesService: ActivitiesServiceType, alertService: PriceAlertServiceType) {
        self.tokenObject = token
        self.viewModel = viewModel
        self.session = session
        self.assetDefinitionStore = assetDefinition
        self.transactionType = transactionType
        self.analyticsCoordinator = analyticsCoordinator
        self.activitiesService = activitiesService
        self.alertService = alertService

        activitiesPageView = ActivitiesPageView(viewModel: .init(activitiesViewModel: .init()), sessions: activitiesService.sessions)
        alertsPageView = PriceAlertsPageView(viewModel: .init(alerts: []))

        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true

        activitiesPageView.delegate = self
        alertsPageView.delegate = self

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar)
        let pageWithFooter = PageViewWithFooter(pageView: tokenInfoPageView, footerBar: footerBar)
        let pages: [PageViewType]
        if Features.isAlertsEnabled && viewModel.balanceViewModel?.ticker != nil {
            pages = [pageWithFooter, activitiesPageView, alertsPageView]
        } else {
            pages = [pageWithFooter, activitiesPageView]
        }

        let containerView = PagesContainerView(pages: pages)

        view.addSubview(containerView)
        NSLayoutConstraint.activate([containerView.anchorsConstraint(to: view)])

        navigationItem.largeTitleDisplayMode = .never

        activitiesSubscriptionKey = activitiesService.subscribableViewModel.subscribe { [weak activitiesPageView] viewModel in
            guard let view = activitiesPageView else { return }

            view.configure(viewModel: .init(activitiesViewModel: viewModel ?? .init(activities: [])))
        }

        alertsSubscriptionKey = alertsSubscribable.subscribe { [weak alertsPageView] alerts in
            guard let view = alertsPageView else { return }

            view.configure(viewModel: .init(alerts: alerts))
        }

        refreshTokenViewControllerUponAssetDefinitionChanges(forTransactionType: transactionType)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    deinit {
        alertsSubscriptionKey.flatMap { alertsSubscribable.unsubscribe($0) }
        activitiesSubscriptionKey.flatMap { activitiesService.subscribableViewModel.unsubscribe($0) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureBalanceViewModel()
        configure(viewModel: viewModel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hideNavigationBarTopSeparatorLine()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        showNavigationBarTopSeparatorLine()
    }

    func configure(viewModel: TokenViewControllerViewModel) {
        self.viewModel = viewModel

        view.backgroundColor = viewModel.backgroundColor
        title = tokenObject.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
        updateNavigationRightBarButtons(tokenScriptFileStatusHandler: tokenScriptFileStatusHandler)

        var viewModel2 = tokenInfoPageView.viewModel
        viewModel2.values = viewModel.chartHistory

        tokenInfoPageView.configure(viewModel: viewModel2)
        alertsPageView.configure(viewModel: .init(alerts: alertsSubscribable.value ?? []))

        let actions = viewModel.actions
        buttonsBar.configure(.combined(buttons: viewModel.actions.count))
        buttonsBar.viewController = self

        for (action, button) in zip(actions, buttonsBar.buttons) {
            button.setTitle(action.name, for: .normal)
            button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
            switch session.account.type {
            case .real:
                if let tokenHolder = generateTokenHolder(), let selection = action.activeExcludingSelection(selectedTokenHolders: [tokenHolder], forWalletAddress: session.account.address, fungibleBalance: viewModel.fungibleBalance) {
                    if selection.denial == nil {
                        button.displayButton = false
                    }
                }
            case .watch:
                button.isEnabled = false
            }
        }
    }

    private func refreshTokenViewControllerUponAssetDefinitionChanges(forTransactionType transactionType: TransactionType) {
        assetDefinitionStore.subscribeToBodyChanges { [weak self] contract in
            guard let strongSelf = self, contract.sameContract(as: transactionType.contract) else { return }

            let viewModel = TokenViewControllerViewModel(transactionType: transactionType, session: strongSelf.session, assetDefinitionStore: strongSelf.assetDefinitionStore, tokenActionsProvider: strongSelf.viewModel.tokenActionsProvider)
            strongSelf.configure(viewModel: viewModel)
        }
        assetDefinitionStore.subscribeToSignatureChanges { [weak self] contract in
            guard let strongSelf = self, contract.sameContract(as: transactionType.contract) else { return }

            let viewModel = TokenViewControllerViewModel(transactionType: transactionType, session: strongSelf.session, assetDefinitionStore: strongSelf.assetDefinitionStore, tokenActionsProvider: strongSelf.viewModel.tokenActionsProvider)
            strongSelf.configure(viewModel: viewModel)
        }
    }

    private func updateNavigationRightBarButtons(tokenScriptFileStatusHandler xmlHandler: XMLHandler) {
        let tokenScriptStatusPromise = xmlHandler.tokenScriptStatus
        if tokenScriptStatusPromise.isPending {
            let label: UIBarButtonItem = .init(title: R.string.localizable.tokenScriptVerifying(), style: .plain, target: nil, action: nil)
            navigationItem.rightBarButtonItem = label

            tokenScriptStatusPromise.done { [weak self] _ in
                self?.updateNavigationRightBarButtons(tokenScriptFileStatusHandler: xmlHandler)
            }.cauterize()
        }

        if let server = xmlHandler.server, let status = tokenScriptStatusPromise.value, server.matches(server: session.server) {
            switch status {
            case .type0NoTokenScript:
                navigationItem.rightBarButtonItem = nil
            case .type1GoodTokenScriptSignatureGoodOrOptional, .type2BadTokenScript:
                let button = createTokenScriptFileStatusButton(withStatus: status, urlOpener: self)
                navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
            }
        } else {
            navigationItem.rightBarButtonItem = nil
        }
    }

    private func configureBalanceViewModel() {
        switch transactionType {
        case .nativeCryptocurrency:
            session.balanceCoordinator.subscribableEthBalanceViewModel.subscribe { [weak self] viewModel in
                guard let celf = self, let viewModel = viewModel else { return }

                celf.tokenInfoPageView.viewModel.title = "\(viewModel.amountShort) \(viewModel.symbol)"
                celf.tokenInfoPageView.viewModel.ticker = viewModel.ticker
                celf.tokenInfoPageView.viewModel.currencyAmount = viewModel.currencyAmount

                celf.configure(viewModel: celf.viewModel)
            }

            session.refresh(.ethBalance)
        case .erc20Token(let token, _, _):
            let amount = EtherNumberFormatter.short.string(from: token.valueBigInt, decimals: token.decimals)
            tokenInfoPageView.viewModel.title = "\(amount) \(token.symbolInPluralForm(withAssetDefinitionStore: assetDefinitionStore))"
            tokenInfoPageView.viewModel.ticker = session.balanceCoordinator.coinTicker(token.addressAndRPCServer)
            session.balanceCoordinator.subscribableTokenBalance(token.addressAndRPCServer).subscribe { [weak self] viewModel in
                guard let strongSelf = self, let viewModel = viewModel else { return }
                strongSelf.tokenInfoPageView.viewModel.currencyAmount = viewModel.currencyAmount
                strongSelf.configure(viewModel: strongSelf.viewModel)
            }
        case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink:
            break
        }
    }

    @objc private func send() {
        delegate?.didTapSend(forTransactionType: transactionType, inViewController: self)
    }

    @objc private func receive() {
        delegate?.didTapReceive(forTransactionType: transactionType, inViewController: self)
    }

    @objc private func actionButtonTapped(sender: UIButton) {
        let actions = viewModel.actions
        for (action, button) in zip(actions, buttonsBar.buttons) where button == sender {
            switch action.type {
            case .swap(let service):
                delegate?.didTapSwap(forTransactionType: transactionType, service: service, inViewController: self)
            case .erc20Send:
                send()
            case .erc20Receive:
                receive()
            case .nftRedeem, .nftSell, .nonFungibleTransfer:
                break
            case .tokenScript:
                if let tokenHolder = generateTokenHolder(), let selection = action.activeExcludingSelection(selectedTokenHolders: [tokenHolder], forWalletAddress: session.account.address, fungibleBalance: viewModel.fungibleBalance) {
                    if let denialMessage = selection.denial {
                        UIAlertController.alert(
                                message: denialMessage,
                                alertButtonTitles: [R.string.localizable.oK()],
                                alertButtonStyles: [.default],
                                viewController: self
                        )
                    } else {
                        //no-op shouldn't have reached here since the button should be disabled. So just do nothing to be safe
                    }
                } else {
                    delegate?.didTap(action: action, transactionType: transactionType, viewController: self)
                }
            case .bridge(let service):
                guard let token = transactionType.swapServiceInputToken, let url = service.url(token: token) else { return }

                delegate?.shouldOpen(url: url, shouldSwitchServer: true, forTransactionType: transactionType, inViewController: self)
            case .buy(let service):
                guard let token = transactionType.swapServiceInputToken, let url = service.url(token: token) else { return }

                logStartOnRamp(name: "Ramp")
                delegate?.shouldOpen(url: url, shouldSwitchServer: false, forTransactionType: transactionType, inViewController: self)
            }
            break
        }
    }

    private func generateTokenHolder() -> TokenHolder? {
        //TODO is it correct to generate the TokenHolder instance once and never replace it? If not, we have to be very careful with subscriptions. Not re-subscribing in an infinite loop
        guard tokenHolder == nil else { return tokenHolder }

        //TODO id 1 for fungibles. Might come back to bite us?
        let hardcodedTokenIdForFungibles = BigUInt(1)
        guard let tokenObject = viewModel.token else { return nil }
        let xmlHandler = XMLHandler(token: tokenObject, assetDefinitionStore: assetDefinitionStore)
        //TODO Event support, if/when designed for fungibles
        let values = xmlHandler.resolveAttributesBypassingCache(withTokenIdOrEvent: .tokenId(tokenId: hardcodedTokenIdForFungibles), server: session.server, account: session.account)
        let subscribablesForAttributeValues = values.values
        let allResolved = subscribablesForAttributeValues.allSatisfy { $0.subscribableValue?.value != nil }
        if allResolved {
            //no-op
        } else {
            for each in subscribablesForAttributeValues {
                guard let subscribable = each.subscribableValue else { continue }
                subscribable.subscribe { [weak self] _ in
                    guard let strongSelf = self else { return }

                    strongSelf.configure(viewModel: strongSelf.viewModel)
                }
            }
        }

        let token = Token(tokenIdOrEvent: .tokenId(tokenId: hardcodedTokenIdForFungibles), tokenType: tokenObject.type, index: 0, name: tokenObject.name, symbol: tokenObject.symbol, status: .available, values: values)
        tokenHolder = TokenHolder(tokens: [token], contractAddress: tokenObject.contractAddress, hasAssetDefinition: true)
        return tokenHolder
    }
}

extension TokenViewController: CanOpenURL2 {
    func open(url: URL) {
        delegate?.didPressOpenWebPage(url, in: self)
    }
}

extension TokenViewController: TokenInfoPageViewDelegate {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, in tokenInfoPageView: TokenInfoPageView) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: session.server, in: self)
    }
}

extension TokenViewController: PriceAlertsPageViewDelegate {
    func addAlertSelected(in view: PriceAlertsPageView) {
        delegate?.didTapAddAlert(for: tokenObject, in: self)
    }

    func editAlertSelected(in view: PriceAlertsPageView, alert: PriceAlert) {
        delegate?.didTapEditAlert(for: tokenObject, alert: alert, in: self)
    }

    func removeAlert(in view: PriceAlertsPageView, indexPath: IndexPath) {
        alertService.remove(indexPath: indexPath).done { _ in
            // no-op
        }.cauterize()
    }

    func updateAlert(in view: PriceAlertsPageView, value: Bool, indexPath: IndexPath) {
        alertService.update(indexPath: indexPath, update: .enabled(value)).done { _ in
            // no-op
        }.cauterize()
    }
}

extension TokenViewController: ActivitiesPageViewDelegate {
    func didTap(activity: Activity, in view: ActivitiesPageView) {
        delegate?.didTap(activity: activity, inViewController: self)
    }

    func didTap(transaction: TransactionInstance, in view: ActivitiesPageView) {
        delegate?.didTap(transaction: transaction, inViewController: self)
    }
}

// MARK: Analytics
extension TokenViewController {
    private func logStartOnRamp(name: String) {
        FiatOnRampCoordinator.logStartOnRamp(name: name, source: .token, analyticsCoordinator: analyticsCoordinator)
    }
}
