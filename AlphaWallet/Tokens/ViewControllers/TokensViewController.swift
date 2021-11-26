// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Result
import StatefulViewController
import PromiseKit
import SwiftUI

protocol TokensViewControllerDelegate: AnyObject {
    func didPressAddHideTokens(viewModel: TokensViewModel)
    func didSelect(token: TokenObject, in viewController: UIViewController)
    func didHide(token: TokenObject, in viewController: UIViewController)
    func didTapOpenConsole(in viewController: UIViewController)
    func scanQRCodeSelected(in viewController: UIViewController)
    func myQRCodeButtonSelected(in viewController: UIViewController)
    func blockieSelected(in viewController: UIViewController)
    func walletConnectSelected(in viewController: UIViewController)
}

class TokensViewController: UIViewController {
    private static let filterViewHeight = DataEntry.Metric.Tokens.Filter.height
    static let addHideTokensViewHeight = DataEntry.Metric.AddHideToken.Header.height

    enum Section {
        case walletSummary
        case filters
        case addHideToken
        case tokens
        case activeWalletSession(count: Int)
    }

    private let tokenCollection: TokenCollection
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: EventsDataStoreProtocol

    private var viewModel: TokensViewModel {
        didSet {
            viewModel.walletConnectSessions = oldValue.walletConnectSessions
            viewModel.isSearchActive = oldValue.isSearchActive
            viewModel.filter = oldValue.filter

            refreshView(viewModel: viewModel)
        }
    }
    private let sessions: ServerDictionary<WalletSession>
    private let account: Wallet
    lazy private var tableViewFilterView = SegmentedControl.tokensSegmentControl(titles: TokensViewModel.segmentedControlTitles)
    lazy private var collectiblesCollectionViewFilterView = SegmentedControl.tokensSegmentControl(titles: TokensViewModel.segmentedControlTitles)
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.register(FungibleTokenViewCell.self)
        tableView.register(EthTokenViewCell.self)
        tableView.register(NonFungibleTokenViewCell.self)
        tableView.register(ServerTableViewCell.self)

        tableView.registerHeaderFooterView(GeneralTableViewSectionHeader<SegmentedControl>.self)
        tableView.registerHeaderFooterView(GeneralTableViewSectionHeader<AddHideTokensView>.self)
        tableView.registerHeaderFooterView(ActiveWalletSessionView.self)
        tableView.registerHeaderFooterView(GeneralTableViewSectionHeader<WalletSummaryView>.self)
        tableView.estimatedRowHeight = DataEntry.Metric.TableView.estimatedRowHeight
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.separatorStyle = .none

        tableView.addSubview(tableViewRefreshControl)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        return tableView
    }()
    private lazy var tableViewRefreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        return control
    }()
    private lazy var collectiblesCollectionViewRefreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)

        return control
    }()
    private lazy var collectiblesCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let numberOfColumns = CGFloat(3)
        let dimension = (UIScreen.main.bounds.size.width / numberOfColumns).rounded(.down)
        let heightForLabel = CGFloat(18)
        layout.itemSize = CGSize(width: dimension, height: dimension + heightForLabel)
        layout.minimumInteritemSpacing = 0
        layout.headerReferenceSize = .init(width: DataEntry.Metric.TableView.headerReferenceSizeWidth, height: TokensViewController.filterViewHeight)
        layout.sectionHeadersPinToVisibleBounds = true

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = viewModel.backgroundColor
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.alwaysBounceVertical = true
        collectionView.register(OpenSeaNonFungibleTokenViewCell.self)
        collectionView.registerSupplementaryView(CollectiblesCollectionViewHeader.self, of: UICollectionView.elementKindSectionHeader)
        collectionView.dataSource = self
        collectionView.isHidden = true
        collectionView.delegate = self
        collectionView.refreshControl = collectiblesCollectionViewRefreshControl

        return collectionView
    }()
    private lazy var blockieImageView: BlockieImageView = .defaultBlockieImageView
    private var currentCollectiblesContractsDisplayed = [AlphaWallet.Address]()
    private let searchController: UISearchController
    private var consoleButton: UIButton {
        return tableViewHeader.consoleButton
    }
    private var promptBackupWalletViewHolder: UIView {
        return tableViewHeader.promptBackupWalletViewHolder
    }
    private var shouldHidePromptBackupWalletViewHolderBecauseSearchIsActive = false
    private var tableViewHeader = {
        return TableViewHeader(consoleButton: UIButton(type: .system), promptBackupWalletViewHolder: UIView())
    }()
    private var isSearchBarConfigured = false
    private var bottomConstraint: NSLayoutConstraint!
    private lazy var keyboardChecker = KeyboardChecker(self, resetHeightDefaultValue: 0, ignoreBottomSafeArea: true)
    private let config: Config
    private let walletConnectCoordinator: WalletConnectCoordinator

    var isConsoleButtonHidden: Bool {
        get {
            return consoleButton.isHidden
        }
        set {
            guard newValue != isConsoleButtonHidden else { return }
            consoleButton.isHidden = newValue
            adjustTableViewHeaderHeightToFitContents()
        }
    }
    var isPromptBackupWalletViewHolderHidden: Bool {
        get {
            return promptBackupWalletViewHolder.isHidden
        }
        set {
            guard newValue != isPromptBackupWalletViewHolderHidden else { return }
            promptBackupWalletViewHolder.isHidden = newValue
            adjustTableViewHeaderHeightToFitContents()
        }
    }

    weak var delegate: TokensViewControllerDelegate?
    //TODO The name "bad" isn't correct. Because it includes "conflicts" too
    var listOfBadTokenScriptFiles: [TokenScriptFileIndices.FileName] = .init() {
        didSet {
            if listOfBadTokenScriptFiles.isEmpty {
                isConsoleButtonHidden = true
            } else {
                consoleButton.titleLabel?.font = Fonts.light(size: 22)
                consoleButton.setTitleColor(Colors.appWhite, for: .normal)
                consoleButton.setTitle(R.string.localizable.tokenScriptShowErrors(), for: .normal)
                consoleButton.bounds.size.height = 44
                consoleButton.isHidden = false
            }
        }
    }
    var promptBackupWalletView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let promptBackupWalletView = promptBackupWalletView {
                promptBackupWalletView.translatesAutoresizingMaskIntoConstraints = false
                promptBackupWalletViewHolder.addSubview(promptBackupWalletView)
                NSLayoutConstraint.activate([
                    promptBackupWalletView.anchorsConstraint(to: promptBackupWalletViewHolder, edgeInsets: .init(top: 7, left: 7, bottom: 4, right: 7)),
                ])

                isPromptBackupWalletViewHolderHidden = shouldHidePromptBackupWalletViewHolderBecauseSearchIsActive
            } else {
                isPromptBackupWalletViewHolderHidden = true
            }
        }
    }
    private var walletSummaryView = WalletSummaryView(edgeInsets: .init(top: 10, left: 0, bottom: 0, right: 0), spacing: 0)
    private var subscriptionKey: Subscribable<WalletBalance>.SubscribableKey?
    private let walletSummarySubscription: Subscribable<WalletBalance>

    private lazy var addHideTokens: AddHideTokensView = {
        let view = AddHideTokensView()
        view.delegate = self
        view.configure()

        return view
    }()

    init(sessions: ServerDictionary<WalletSession>,
         account: Wallet,
         tokenCollection: TokenCollection,
         assetDefinitionStore: AssetDefinitionStore,
         eventsDataStore: EventsDataStoreProtocol,
         filterTokensCoordinator: FilterTokensCoordinator,
         config: Config,
         walletConnectCoordinator: WalletConnectCoordinator,
         walletBalanceCoordinator: WalletBalanceCoordinatorType
    ) {
        self.sessions = sessions
        self.account = account
        self.tokenCollection = tokenCollection
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
        self.config = config
        self.walletConnectCoordinator = walletConnectCoordinator
        walletSummarySubscription = walletBalanceCoordinator.subscribableWalletBalance(wallet: account)

        viewModel = TokensViewModel(filterTokensCoordinator: filterTokensCoordinator, tokens: [])
        searchController = UISearchController(searchResultsController: nil)

        super.init(nibName: nil, bundle: nil)
        handleTokenCollectionUpdates()
        searchController.delegate = self
        view.backgroundColor = viewModel.backgroundColor

        tableViewFilterView.delegate = self
        tableViewFilterView.translatesAutoresizingMaskIntoConstraints = false

        collectiblesCollectionViewFilterView.delegate = self
        collectiblesCollectionViewFilterView.translatesAutoresizingMaskIntoConstraints = false

        consoleButton.addTarget(self, action: #selector(openConsole), for: .touchUpInside)

        view.addSubview(tableView)
        view.addSubview(collectiblesCollectionView)

        bottomConstraint = tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        keyboardChecker.constraint = bottomConstraint

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomConstraint,
            collectiblesCollectionView.anchorsConstraint(to: tableView)
        ])

        errorView = ErrorView(onRetry: { [weak self] in
            self?.startLoading()
            self?.tokenCollection.fetch()
        })
        loadingView = LoadingView()
        emptyView = EmptyView.tokensEmptyView(completion: { [weak self] in
            self?.startLoading()
            self?.tokenCollection.fetch()
        })

        refreshView(viewModel: viewModel)

        setupFilteringWithKeyword()

        //NOTE: https://github.com/AlphaWallet/alpha-wallet-ios/issues/3255
        let myqrCodeBarButton = UIBarButtonItem.myqrCodeBarButton(self, selector: #selector(myQRCodeButtonSelected))
        let qrCodeBarButton = UIBarButtonItem.qrCodeBarButton(self, selector: #selector(scanQRCodeButtonSelected))
        myqrCodeBarButton.imageInsets = .init(top: 0, left: 0, bottom: 0, right: 0)
        qrCodeBarButton.imageInsets = .init(top: 0, left: 10, bottom: 0, right: -10)

        navigationItem.rightBarButtonItems = [
            myqrCodeBarButton,
            qrCodeBarButton
        ]
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: blockieImageView)
    
        walletConnectCoordinator.sessionsToURLServersMap.subscribe { [weak self] value in
            guard let strongSelf = self, let sessions = value else { return }

            let viewModel = strongSelf.viewModel
            viewModel.walletConnectSessions = sessions.count
            strongSelf.viewModel = viewModel

            strongSelf.tableView.reloadData()
        }
        blockieImageView.addTarget(self, action: #selector(blockieButtonSelected), for: .touchUpInside)
        self.reloadWalletSummaryView(with: walletSummarySubscription.value)
        subscriptionKey = walletSummarySubscription.subscribe { [weak self] balance in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.reloadWalletSummaryView(with: balance)
            }
        }
        navigationItem.largeTitleDisplayMode = .never
    }

    deinit {
        subscriptionKey.flatMap { walletSummarySubscription.unsubscribe($0) }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.applyTintAdjustment()
        hidesBottomBarWhenPushed = false
        hideNavigationBarTopSeparatorLine()
        fetch()
        fixNavigationBarAndStatusBarBackgroundColorForiOS13Dot1()
        keyboardChecker.viewWillAppear()
        //getWalletName()
        getWalletBlockie()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        keyboardChecker.viewWillDisappear()
    }

    @objc private func blockieButtonSelected(_ sender: UIButton) {
        delegate?.blockieSelected(in: self)
    }

    @objc private func scanQRCodeButtonSelected(_ sender: UIBarButtonItem) {
        delegate?.scanQRCodeSelected(in: self)
    }

    @objc private func myQRCodeButtonSelected(_ sender: UIBarButtonItem) {
        delegate?.myQRCodeButtonSelected(in: self)
    }

    private func getWalletName() {
        title = viewModel.walletDefaultTitle

        firstly {
            GetWalletNameCoordinator(config: config).getName(forAddress: account.address)
        }.done { [weak self] name in
            guard let strongSelf = self else { return }
            strongSelf.navigationItem.title = name ?? strongSelf.viewModel.walletDefaultTitle
        }.cauterize()
    }

    private func getWalletBlockie() {
        let generator = BlockiesGenerator()
        generator.promise(address: account.address).done { [weak self] value in
            self?.blockieImageView.image = value
        }.catch { [weak self] _ in
            self?.blockieImageView.image = nil
        }
    }

    @objc func pullToRefresh() {
        tableViewRefreshControl.beginRefreshing()
        collectiblesCollectionViewRefreshControl.beginRefreshing()
        fetch()
    }

    @objc func openConsole() {
        delegate?.didTapOpenConsole(in: self)
    }

    func fetch() {
        startLoading()
        tokenCollection.fetch()
    }

    override func viewDidLayoutSubviews() {
        //viewDidLayoutSubviews() is called many times
        //configureSearchBarOnce()
    }

    private func reloadTableData() {
        tableView.reloadData()
    }

    private func reload() {
        isPromptBackupWalletViewHolderHidden = !(viewModel.shouldShowBackupPromptViewHolder && !promptBackupWalletViewHolder.subviews.isEmpty) || shouldHidePromptBackupWalletViewHolderBecauseSearchIsActive
        collectiblesCollectionView.isHidden = !viewModel.shouldShowCollectiblesCollectionView
        reloadTableData()
        if viewModel.hasContent {
            if viewModel.shouldShowCollectiblesCollectionView {
                let contractsForCollectibles = contractsForCollectiblesFromViewModel()
                if contractsForCollectibles != currentCollectiblesContractsDisplayed {
                    currentCollectiblesContractsDisplayed = contractsForCollectibles
                    collectiblesCollectionView.reloadData()
                }
                tableView.dataSource = nil
            } else {
                tableView.dataSource = self
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func refreshView(viewModel: TokensViewModel) {
        view.backgroundColor = viewModel.backgroundColor
        tableView.backgroundColor = viewModel.backgroundColor
    }

    //Reloading the collectibles tab is very obvious visually, with the flashing images even if there are no changes. So we used this to check if the list of collectibles have changed, if not, don't refresh. We could have used a library that tracks diff, but that is overkill and one more dependency
    private func contractsForCollectiblesFromViewModel() -> [AlphaWallet.Address] {
        var contractsForCollectibles = [AlphaWallet.Address]()
        for i in (0..<viewModel.numberOfItems()) {
            switch viewModel.item(for: i, section: 0) {
            case .rpcServer:
                break
            case .tokenObject(let token):
                contractsForCollectibles.append(token.contractAddress)
            }
        }
        return contractsForCollectibles
    }

    private func handleTokenCollectionUpdates() {
        tokenCollection.subscribe { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let viewModel):
                strongSelf.viewModel = viewModel
                strongSelf.endLoading()
            case .failure(let error):
                strongSelf.endLoading(error: error)
            }
            strongSelf.reload()

            if strongSelf.tableViewRefreshControl.isRefreshing {
                strongSelf.tableViewRefreshControl.endRefreshing()
            }
            if strongSelf.collectiblesCollectionViewRefreshControl.isRefreshing {
                strongSelf.collectiblesCollectionViewRefreshControl.endRefreshing()
            }
        }
    }

    private func adjustTableViewHeaderHeightToFitContents() {
        let size = tableViewHeader.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        tableViewHeader.bounds.size.height = size.height
        tableView.tableHeaderView = tableViewHeader
    }

    private static func reloadWalletSummaryView(_ walletSummaryView: WalletSummaryView, with balance: WalletBalance?) {
        let summary = balance.map { WalletSummary(balances: [$0]) }
        walletSummaryView.configure(viewModel: .init(summary: summary, alignment: .center))
    }
    
    private func reloadWalletSummaryView(with balance: WalletBalance?) {
        let summary = balance.map { WalletSummary(balances: [$0]) }
        title = WalletSummaryViewModel(summary: summary).balanceAttributedString.string
    }
    
}

extension TokensViewController: StatefulViewController {
    //Always return true, otherwise users will be stuck in the assets sub-tab when they have no assets
    func hasContent() -> Bool {
        return true
    }
}

extension TokensViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch viewModel.item(for: indexPath.row, section: indexPath.section) {
        case .rpcServer:
            break
        case .tokenObject(let token):
            delegate?.didSelect(token: token, in: self)
        }
    }

    //Hide the footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch viewModel.sections[section] {
        case .walletSummary:
            return 80
        case .filters:
            return TokensViewController.filterViewHeight
        case .addHideToken:
            return TokensViewController.addHideTokensViewHeight
        case .activeWalletSession:
            return 80
        case .tokens:
            return 0.01
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch viewModel.sections[section] {
        case .walletSummary:
            let header: TokensViewController.GeneralTableViewSectionHeader<WalletSummaryView> = tableView.dequeueReusableHeaderFooterView()
            header.subview = walletSummaryView
            return header
        case .filters:
            let header: TokensViewController.GeneralTableViewSectionHeader<SegmentedControl> = tableView.dequeueReusableHeaderFooterView()
            header.subview = tableViewFilterView
            header.useSeparatorLine = false
            header.subview?.backgroundColor = Colors.headerThemeColor
            return header
        case .addHideToken:
            let header: TokensViewController.GeneralTableViewSectionHeader<AddHideTokensView> = tableView.dequeueReusableHeaderFooterView()
            header.subview = addHideTokens
            header.subview?.backgroundColor = Colors.clear
            header.useSeparatorLine = false
            return header
        case .activeWalletSession(let count):
            let header: ActiveWalletSessionView = tableView.dequeueReusableHeaderFooterView()
            header.configure(viewModel: .init(count: count))
            header.delegate = self

            return header
        case .tokens:
            return nil
        }
    }
}

extension TokensViewController: ActiveWalletSessionViewDelegate {

    func view(_ view: ActiveWalletSessionView, didSelectTap sender: UITapGestureRecognizer) {
        delegate?.walletConnectSelected(in: self)
    }
}

extension TokensViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch viewModel.sections[indexPath.section] {
        case .addHideToken, .walletSummary, .filters, .activeWalletSession:
            return UITableViewCell()
        case .tokens:
            switch viewModel.item(for: indexPath.row, section: indexPath.section) {
            case .rpcServer(_):
                return UITableViewCell()
            case .tokenObject(let token):
                let server = token.server
                let session = sessions[server]

                switch token.type {
                case .nativeCryptocurrency:
                    let cell: EthTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
                    cell.configure(viewModel: .init(
                        token: token,
                        ticker: session.balanceCoordinator.coinTicker(token.addressAndRPCServer),
                        currencyAmount: session.balanceCoordinator.ethBalanceViewModel.currencyAmountWithoutSymbol,
                        assetDefinitionStore: assetDefinitionStore
                    ))

                    return cell
                case .erc20:
                    let cell: FungibleTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
                    cell.configure(viewModel: .init(token: token,
                        assetDefinitionStore: assetDefinitionStore,
                        isVisible: isVisible,
                        ticker: session.balanceCoordinator.coinTicker(token.addressAndRPCServer)
                    ))
                    return cell
                case .erc721, .erc721ForTickets, .erc1155:
                    let cell: NonFungibleTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
                    cell.configure(viewModel: .init(token: token, server: server, assetDefinitionStore: assetDefinitionStore))
                    return cell
                case .erc875:
                    let cell: NonFungibleTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
                    cell.configure(viewModel: .init(token: token, server: server, assetDefinitionStore: assetDefinitionStore))
                    return cell
                }
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch viewModel.sections[section] {
        case .addHideToken, .walletSummary, .filters, .activeWalletSession:
            return 0
        case .tokens:
            return viewModel.numberOfItems()
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        viewModel.sections.count
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        switch viewModel.sections[indexPath.section] {
        case .addHideToken, .walletSummary, .filters, .activeWalletSession:
            return nil
        case .tokens:
            return trailingSwipeActionsConfiguration(forRowAt: indexPath)
        }
    }

    private func trailingSwipeActionsConfiguration(forRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        switch viewModel.item(for: indexPath.row, section: indexPath.section) {
        case .rpcServer:
            return nil
        case .tokenObject(let token):
            let title = R.string.localizable.walletsHideTokenTitle()
            let hideAction = UIContextualAction(style: .destructive, title: title) { [weak self] (_, _, completionHandler) in
                guard let strongSelf = self else { return }

                strongSelf.delegate?.didHide(token: token, in: strongSelf)

                let didHideToken = strongSelf.viewModel.markTokenHidden(token: token)
                if didHideToken {
                    strongSelf.tableView.deleteRows(at: [indexPath], with: .automatic)
                } else {
                    strongSelf.reloadTableData()
                }

                completionHandler(didHideToken)
            }

            hideAction.backgroundColor = R.color.danger()
            hideAction.image = R.image.hideToken()
            let configuration = UISwipeActionsConfiguration(actions: [hideAction])
            configuration.performsFirstActionWithFullSwipe = true

            return configuration
        }
    }
}

extension TokensViewController: SegmentedControlDelegate {
    func didTapSegment(atSelection selection: SegmentedControl.Selection, inSegmentedControl segmentedControl: SegmentedControl) {
        guard let filter = viewModel.convertSegmentedControlSelectionToFilter(selection) else { return }
        apply(filter: filter, withSegmentAtSelection: selection)
    }

    private func apply(filter: WalletFilter, withSegmentAtSelection selection: SegmentedControl.Selection?) {
        let previousFilter = viewModel.filter
        viewModel.filter = filter
        reload()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            //Important to update the segmented control (and hence add the segmented control back to the table) after they have been re-added to the table header through the table reload. Otherwise adding to the table header will break the animation for segmented control
            if let selection = selection {
                self.collectiblesCollectionViewFilterView.selection = selection
                self.tableViewFilterView.selection = selection
            }
        }
        //Exit search if user tapped on the wallet filter. Careful to not trigger an infinite recursion between changing the filter by "category" and search keywords which are all based on filters
        if previousFilter == filter {
            //do nothing
        } else {
            switch filter {
            case .all, .currencyOnly, .assetsOnly, .collectiblesOnly, .type:
                searchController.isActive = false
            case .keyword:
                break
            }
        }
    }
}

extension TokensViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        //Defensive check to make sure we don't return the wrong count. iOS might decide to load (the first time especially) the collection view at some point even if we don't switch to it, thus getting the wrong count and then at some point asking for a cell for those non-existent rows/items. E.g 10 tokens total, only 3 are collectibles and asked for the 6th cell
        switch viewModel.filter {
        case .collectiblesOnly:
            return viewModel.numberOfItems()
        case .all, .currencyOnly, .assetsOnly, .keyword, .type:
            return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch viewModel.item(for: indexPath.row, section: indexPath.section) {
        case .rpcServer:
            return UICollectionViewCell()
        case .tokenObject(let token):
            let server = token.server
            let session = sessions[server]
            let cell: OpenSeaNonFungibleTokenViewCell = collectionView.dequeueReusableCell(for: indexPath)

            cell.configure(viewModel: .init(config: session.config, token: token, forWallet: account, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore))
            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header: CollectiblesCollectionViewHeader = collectionView.dequeueReusableSupplementaryView(ofKind: kind, for: indexPath)
        header.filterView = collectiblesCollectionViewFilterView
        return header
    }
}

extension TokensViewController: UISearchControllerDelegate {
    func willPresentSearchController(_ searchController: UISearchController) {
        viewModel.isSearchActive = true
    }

    func willDismissSearchController(_ searchController: UISearchController) {
        viewModel.isSearchActive = false
    }
}

extension TokensViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectiblesCollectionView.deselectItem(at: indexPath, animated: true)

        switch viewModel.item(for: indexPath.item, section: indexPath.section) {
        case .rpcServer:
            break
        case .tokenObject(let token):
            delegate?.didSelect(token: token, in: self)
        }
    }
}

extension TokensViewController: UISearchResultsUpdating {
    //At least on iOS 13 beta on a device. updateSearchResults(for:) is called when we set `searchController.isActive = false` to dismiss search (because user tapped on a filter), but the value of `searchController.isActive` remains `false` during the call, hence the async.
    //This behavior is not observed in iOS 12, simulator
    func updateSearchResults(for searchController: UISearchController) {
        DispatchQueue.main.async {
            self.processSearchWithKeywords()
        }
    }

    private func processSearchWithKeywords() {
        shouldHidePromptBackupWalletViewHolderBecauseSearchIsActive = searchController.isActive
        guard searchController.isActive else {
            switch viewModel.filter {
            case .all, .currencyOnly, .assetsOnly, .collectiblesOnly, .type:
                break
            case .keyword:
                //Handle when user taps Cancel button to stop search
                setDefaultFilter()
            }
            return
        }
        let keyword = searchController.searchBar.text ?? ""
        updateResults(withKeyword: keyword)
    }

    private func updateResults(withKeyword keyword: String) {
        tableViewFilterView.selection = .unselected
        apply(filter: .keyword(keyword), withSegmentAtSelection: nil)
    }

    private func setDefaultFilter() {
        apply(filter: .all, withSegmentAtSelection: .selected(0))
    }
}

///Support searching/filtering tokens with keywords. This extension is set up so it's easier to copy and paste this functionality elsewhere
extension TokensViewController {
    private func makeSwitchToAnotherTabWorkWhileFiltering() {
        definesPresentationContext = true
    }

    private func doNotDimTableViewToReuseTableForFilteringResult() {
        searchController.dimsBackgroundDuringPresentation = false
    }

    private func wireUpSearchController() {
        searchController.searchResultsUpdater = self
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = true
    }

    private func fixNavigationBarAndStatusBarBackgroundColorForiOS13Dot1() {
        view.superview?.backgroundColor = Colors.headerThemeColor
    }

    private func setupFilteringWithKeyword() {
        //wireUpSearchController()
        TokensViewController.functional.fixTableViewBackgroundColor(tableView: tableView, backgroundColor: UIColor.clear)
        doNotDimTableViewToReuseTableForFilteringResult()
        makeSwitchToAnotherTabWorkWhileFiltering()
    }

    //Makes a difference where this is called from. Can't be too early
    private func configureSearchBarOnce() {
        guard !isSearchBarConfigured else { return }
        isSearchBarConfigured = true

        if let placeholderLabel = searchController.searchBar.firstSubview(ofType: UILabel.self) {
            placeholderLabel.textColor = Colors.lightGray
        }
        if let textField = searchController.searchBar.firstSubview(ofType: UITextField.self) {
            textField.textColor = Colors.appText
            if let imageView = textField.leftView as? UIImageView {
                imageView.image = imageView.image?.withRenderingMode(.alwaysTemplate)
                imageView.tintColor = Colors.appText
            }
        }
        //Hack to hide the horizontal separator below the search bar
        searchController.searchBar.superview?.firstSubview(ofType: UIImageView.self)?.isHidden = true
        searchController.searchBar.backgroundColor = Colors.headerThemeColor
    }
}

extension TokensViewController: AddHideTokensViewDelegate {
    func view(_ view: AddHideTokensView, didSelectAddHideTokensButton sender: UIButton) {
        delegate?.didPressAddHideTokens(viewModel: viewModel)
    }
}

extension TokensViewController {
    class functional {}
}

extension TokensViewController.functional {
    static func fixTableViewBackgroundColor(tableView: UITableView, backgroundColor: UIColor) {
        let v = UIView()
        v.backgroundColor = backgroundColor
        tableView.backgroundView?.backgroundColor = backgroundColor
        tableView.backgroundView = v
    }
}
