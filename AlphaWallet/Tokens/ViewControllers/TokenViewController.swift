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
}

class TokenViewController: UIViewController {
    private let roundedBackground = RoundedBackground()
    private var viewModel: TokenViewControllerViewModel
    private var tokenHolder: TokenHolder?
    private let tokenObject: TokenObject
    private let session: WalletSession
    private let tokensDataStore: TokensDataStore
    private let assetDefinitionStore: AssetDefinitionStore
    private let transactionType: TransactionType
    private let analyticsCoordinator: AnalyticsCoordinator
    private let buttonsBar = ButtonsBar(configuration: .combined(buttons: 2))
    private lazy var tokenScriptFileStatusHandler = XMLHandler(token: tokenObject, assetDefinitionStore: assetDefinitionStore)
    weak var delegate: TokenViewControllerDelegate?

    private lazy var tokenInfoPageView: TokenInfoPageView = {
        let view = TokenInfoPageView(server: session.server, token: tokenObject, transactionType: transactionType)
        view.delegate = self

        return view
    }()
    private lazy var activityPageView: ActivityPageView = {
        let viewModel: ActivityPageViewModel = .init(activitiesViewModel: .init())
        let view = ActivityPageView(viewModel: viewModel, sessions: sessions)
        view.delegate = self

        return view
    }()
    private lazy var alertsPageView = AlertsPageView()
    private let sessions: ServerDictionary<WalletSession>
    private let activitiesService: ActivitiesServiceType
    
    init(session: WalletSession, tokensDataStore: TokensDataStore, assetDefinition: AssetDefinitionStore, transactionType: TransactionType, analyticsCoordinator: AnalyticsCoordinator, token: TokenObject, viewModel: TokenViewControllerViewModel, activitiesService: ActivitiesServiceType, sessions: ServerDictionary<WalletSession>) {
        self.tokenObject = token
        self.viewModel = viewModel
        self.session = session
        self.sessions = sessions
        self.tokensDataStore = tokensDataStore
        self.assetDefinitionStore = assetDefinition
        self.transactionType = transactionType
        self.analyticsCoordinator = analyticsCoordinator
        self.activitiesService = activitiesService
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        let containerView = TokenPagesContainerView(pages: [tokenInfoPageView, activityPageView])
        roundedBackground.addSubview(containerView)

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar)
        roundedBackground.addSubview(footerBar)

        NSLayoutConstraint.activate([
            footerBar.anchorsConstraint(to: view),

            containerView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))

        navigationItem.largeTitleDisplayMode = .never

        activitiesService.subscribableViewModel.subscribe { [weak self] viewModel in
            guard let strongSelf = self, let viewModel = viewModel else { return }

            NSLog("KKKK-ST: subscribableViewModel (on next): \(viewModel.itemsCount)")
            strongSelf.activityPageView.configure(viewModel: .init(activitiesViewModel: viewModel))
        }
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureBalanceViewModel()
        configure(viewModel: viewModel)
    }

    func configure(viewModel: TokenViewControllerViewModel) {
        self.viewModel = viewModel

        view.backgroundColor = viewModel.backgroundColor
        title = tokenObject.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
        updateNavigationRightBarButtons(tokenScriptFileStatusHandler: tokenScriptFileStatusHandler)

        var viewModel2 = tokenInfoPageView.viewModel
        viewModel2.values = viewModel.chartHistory

        tokenInfoPageView.configure(viewModel: viewModel2)

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
            session.balanceViewModel.subscribe { [weak self] viewModel in
                guard let celf = self, let viewModel = viewModel else { return }

                celf.tokenInfoPageView.viewModel.title = "\(viewModel.amountShort) \(viewModel.symbol)"
                let etherToken = TokensDataStore.etherToken(forServer: celf.session.server)
                celf.tokenInfoPageView.viewModel.ticker = celf.tokensDataStore.coinTicker(for: etherToken)
                celf.tokenInfoPageView.viewModel.currencyAmount = celf.session.balanceCoordinator.viewModel.currencyAmount

                celf.configure(viewModel: celf.viewModel)
            }

            session.refresh(.ethBalance)
        case .ERC20Token(let token, _, _):
            let amount = EtherNumberFormatter.short.string(from: token.valueBigInt, decimals: token.decimals)
            //Note that if we want to display the token name directly from token.name, we have to be careful that DAI token's name has trailing \0
            tokenInfoPageView.viewModel.title = "\(amount) \(token.symbolInPluralForm(withAssetDefinitionStore: assetDefinitionStore))"

            let etherToken = TokensDataStore.etherToken(forServer: session.server)

            tokenInfoPageView.viewModel.ticker = tokensDataStore.coinTicker(for: etherToken)
            tokenInfoPageView.viewModel.currencyAmount = session.balanceCoordinator.viewModel.currencyAmount

            configure(viewModel: viewModel)
        case .ERC875Token, .ERC875TokenOrder, .ERC721Token, .ERC721ForTicketToken, .dapp, .tokenScript, .claimPaidErc875MagicLink:
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
            case .xDaiBridge:
                delegate?.shouldOpen(url: Constants.xDaiBridge, shouldSwitchServer: true, forTransactionType: transactionType, inViewController: self)
            case .buy(let service):
                var tokenObject: TokenActionsServiceKey?
                switch transactionType {
                case .nativeCryptocurrency(let token, _, _):
                    tokenObject = TokenActionsServiceKey(tokenObject: token)
                case .ERC20Token(let token, _, _):
                    tokenObject = TokenActionsServiceKey(tokenObject: token)
                case .ERC875Token, .ERC875TokenOrder, .ERC721Token, .ERC721ForTicketToken, .dapp, .tokenScript, .claimPaidErc875MagicLink:
                    tokenObject = .none
                }

                guard let token = tokenObject, let url = service.url(token: token) else { return }

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
        let values = xmlHandler.resolveAttributesBypassingCache(withTokenIdOrEvent: .tokenId(tokenId: hardcodedTokenIdForFungibles), server: self.session.server, account: self.session.account)
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

extension TokenViewController: ActivityPageViewDelegate {
    func didTap(activity: Activity, in view: ActivityPageView) {
        delegate?.didTap(activity: activity, inViewController: self)
    }

    func didTap(transaction: TransactionInstance, in view: ActivityPageView) {
        delegate?.didTap(transaction: transaction, inViewController: self)
    }
}

// MARK: Analytics
extension TokenViewController {
    private func logStartOnRamp(name: String) {
        analyticsCoordinator.log(navigation: Analytics.Navigation.onRamp, properties: [Analytics.Properties.name.rawValue: name])
    }
}
