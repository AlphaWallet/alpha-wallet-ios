// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt
import PromiseKit

protocol TokenViewControllerDelegate: class, CanOpenURL {
    func didTapSwap(forTransactionType transactionType: TransactionType, service: SwapTokenURLProviderType, inViewController viewController: TokenViewController)
    func shouldOpen(url: URL, shouldSwitchServer: Bool, forTransactionType transactionType: TransactionType, inViewController viewController: TokenViewController)
    func didTapSend(forTransactionType transactionType: TransactionType, inViewController viewController: TokenViewController)
    func didTapReceive(forTransactionType transactionType: TransactionType, inViewController viewController: TokenViewController)
    func didTap(transaction: TransactionInstance, inViewController viewController: TokenViewController)
    func didTap(action: TokenInstanceAction, transactionType: TransactionType, viewController: TokenViewController)
}

class TokenViewController: UIViewController {
    private let headerViewRefreshInterval: TimeInterval = 5.0
    private let roundedBackground = RoundedBackground()
    lazy private var header = {
        return TokenViewControllerHeaderView(contract: transactionType.contract)
    }()
    lazy private var headerViewModel = SendHeaderViewViewModel(server: session.server, token: token, transactionType: transactionType)
    private var viewModel: TokenViewControllerViewModel?
    private var tokenHolder: TokenHolder?
    private let token: TokenObject
    private let session: WalletSession
    private let tokensDataStore: TokensDataStore
    private let assetDefinitionStore: AssetDefinitionStore
    private let transactionType: TransactionType
    private let analyticsCoordinator: AnalyticsCoordinator
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let buttonsBar = ButtonsBar(configuration: .combined(buttons: 2))
    private lazy var tokenScriptFileStatusHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
    private var headerRefreshTimer: Timer!

    //transactions recevied
    private var kaleidoDataSource = [KaleidoTransaction]()

    weak var delegate: TokenViewControllerDelegate?

    init(session: WalletSession, tokensDataStore: TokensDataStore, assetDefinition: AssetDefinitionStore, transactionType: TransactionType, analyticsCoordinator: AnalyticsCoordinator, token: TokenObject) {
        self.token = token
        self.session = session
        self.tokensDataStore = tokensDataStore
        self.assetDefinitionStore = assetDefinition
        self.transactionType = transactionType
        self.analyticsCoordinator = analyticsCoordinator

        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        header.delegate = self

        tableView.register(TokenViewControllerTransactionCell.self)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = header
        tableView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(tableView)

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar)
        roundedBackground.addSubview(footerBar)

        configureBalanceViewModel()

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),

            tableView.anchorsConstraint(to: roundedBackground),
            footerBar.anchorsConstraint(to: view),

            roundedBackground.createConstraintsWithContainer(view: view),
        ])

        headerRefreshTimer = Timer(timeInterval: headerViewRefreshInterval, repeats: true) { [weak self] _ in
            self?.refreshHeaderView()
        }
        RunLoop.main.add(headerRefreshTimer, forMode: .default)
        navigationItem.largeTitleDisplayMode = .never
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let buttonsBarHolder = buttonsBar.superview else {
            tableView.contentInset = .zero
            return
        }
        //TODO We are basically calculating the bottom safe area here. Don't rely on the internals of how buttonsBar and it's parent are laid out
        if buttonsBar.isEmpty {
            tableView.contentInset = .init(top: 0, left: 0, bottom: buttonsBarHolder.frame.size.height - buttonsBar.frame.size.height, right: 0)
        } else {
            tableView.contentInset = .init(top: 0, left: 0, bottom: tableView.frame.size.height - buttonsBarHolder.frame.origin.y, right: 0)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // in purpose of existig UI reusing for Kaleido integration testing
        fetchKaleidoTransactions()
    }

    func configure(viewModel: TokenViewControllerViewModel) {
        self.viewModel = viewModel
        view.backgroundColor = viewModel.backgroundColor

        updateNavigationRightBarButtons(tokenScriptFileStatusHandler: tokenScriptFileStatusHandler)

        header.sendHeaderView.configure(viewModel: headerViewModel)
        header.frame.size.height = header.systemLayoutSizeFitting(.zero).height

        tableView.tableHeaderView = header

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

        tableView.reloadData()
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
    // MARK: created in purpose of existig UI reusing for Kaleido integration testing
    private func fetchKaleidoTransactions() {
        KaleidoService.getTransactions { [weak self] transactions in
            self?.kaleidoDataSource = transactions
            self?.tableView.reloadData()
        }
    }

    private func configureBalanceViewModel() {
        switch transactionType {
        case .nativeCryptocurrency:
            session.balanceViewModel.subscribe { [weak self] viewModel in
                guard let celf = self, let viewModel = viewModel else { return }
                let amount = viewModel.amountShort
                celf.headerViewModel.title = "\(amount) \(viewModel.symbol)"
                let etherToken = TokensDataStore.etherToken(forServer: celf.session.server)
                let ticker = celf.tokensDataStore.coinTicker(for: etherToken)
                celf.headerViewModel.ticker = ticker
                celf.headerViewModel.currencyAmount = celf.session.balanceCoordinator.viewModel.currencyAmount
                if let viewModel = celf.viewModel {
                    celf.configure(viewModel: viewModel)
                }
            }
            session.refresh(.ethBalance)
        case .ERC20Token(let token, _, _):
            let amount = EtherNumberFormatter.short.string(from: token.valueBigInt, decimals: token.decimals)
            //Note that if we want to display the token name directly from token.name, we have to be careful that DAI token's name has trailing \0
            headerViewModel.title = "\(amount) \(token.symbolInPluralForm(withAssetDefinitionStore: assetDefinitionStore))"

            let etherToken = TokensDataStore.etherToken(forServer: session.server)
            let ticker = tokensDataStore.coinTicker(for: etherToken)
            headerViewModel.ticker = ticker
            headerViewModel.currencyAmount = session.balanceCoordinator.viewModel.currencyAmount
            if let viewModel = self.viewModel {
                configure(viewModel: viewModel)
            }
        case .ERC875Token, .ERC875TokenOrder, .ERC721Token, .ERC721ForTicketToken, .dapp, .tokenScript, .claimPaidErc875MagicLink:
            break
        }

        title = token.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
    }

    @objc private func send() {
        delegate?.didTapSend(forTransactionType: transactionType, inViewController: self)
    }

    @objc private func receive() {
        delegate?.didTapReceive(forTransactionType: transactionType, inViewController: self)
    }

    @objc private func actionButtonTapped(sender: UIButton) {
        guard let viewModel = viewModel else { return }
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
                    delegate?.didTap(action: action, transactionType: transactionType, viewController: self)
                }
            case .xDaiBridge:
                delegate?.shouldOpen(url: Constants.xDaiBridge, shouldSwitchServer: true, forTransactionType: transactionType, inViewController: self)
            case .buy(let service):
                var tokenObject: TokenObject?
                switch transactionType {
                case .nativeCryptocurrency(let token, _, _):
                    tokenObject = token
                case .ERC20Token(let token, _, _):
                    tokenObject = token
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
        guard let tokenObject = viewModel?.token else { return nil }
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
                    guard let viewModel = strongSelf.viewModel else { return }
                    strongSelf.configure(viewModel: viewModel)
                }
            }
        }

        let token = Token(tokenIdOrEvent: .tokenId(tokenId: hardcodedTokenIdForFungibles), tokenType: tokenObject.type, index: 0, name: tokenObject.name, symbol: tokenObject.symbol, status: .available, values: values)
        tokenHolder = TokenHolder(tokens: [token], contractAddress: tokenObject.contractAddress, hasAssetDefinition: true)
        return tokenHolder
    }
}

extension TokenViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: TokenViewControllerTransactionCell = tableView.dequeueReusableCell(for: indexPath)
        
        // MARK: commented in purpose of existig UI reusing for Kaleido integration testing
       // if let transaction = viewModel?.recentTransactions[indexPath.row] {
//            let viewModel = TokenViewControllerTransactionCellViewModel(
//                    transaction: transaction,
//                    config: session.config,
//                    chainState: session.chainState,
//                    currentWallet: session.account
//            )
//            cell.configure(viewModel: viewModel)

        if !self.kaleidoDataSource.isEmpty {
            cell.configure(kaleidoModel: self.kaleidoDataSource[indexPath.row])
        } else {
            cell.configureEmpty()
        }
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return kaleidoDataSource.count
        // MARK: commented in purpose of existig UI reusing for Kaleido integration testing
        //return viewModel?.recentTransactions.count ?? 0
    }
}

extension TokenViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let alert = UIAlertController(title: "Transaction details",
                                      message: "\(self.kaleidoDataSource[indexPath.row])",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
        // MARK: commented in purpose of existig UI reusing for Kaleido integration testing
        //guard let transaction = viewModel?.recentTransactions[indexPath.row] else { return }
        //delegate?.didTap(transaction: transaction, inViewController: self)
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 94
    }
}

extension TokenViewController: CanOpenURL2 {
    func open(url: URL) {
        delegate?.didPressOpenWebPage(url, in: self)
    }
}

extension TokenViewController: TokenViewControllerHeaderViewDelegate {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, inHeaderView: TokenViewControllerHeaderView) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: session.server, in: self)
    }

    func didShowHideMarketPrice(inHeaderView: TokenViewControllerHeaderView) {
        refreshHeaderView()
    }

    @objc private func refreshHeaderView() {
        headerViewModel.isShowingValue.toggle()
        header.sendHeaderView.configure(viewModel: headerViewModel)
    }
}

// MARK: Analytics
extension TokenViewController {
    private func logStartOnRamp(name: String) {
        analyticsCoordinator.log(navigation: Analytics.Navigation.onRamp, properties: [Analytics.Properties.name.rawValue: name])
    }
}
