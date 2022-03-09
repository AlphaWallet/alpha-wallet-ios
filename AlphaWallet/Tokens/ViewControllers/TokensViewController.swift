// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Result
import StatefulViewController
import PromiseKit
import Combine

protocol TokensViewControllerDelegate: AnyObject {
    func viewWillAppear(in viewController: UIViewController)
    func didSelect(token: TokenObject, in viewController: UIViewController)
    func didHide(token: TokenObject, in viewController: UIViewController)
    func didTapOpenConsole(in viewController: UIViewController)
    func walletConnectSelected(in viewController: UIViewController)
    func whereAreMyTokensSelected(in viewController: UIViewController)
}

class TokensViewController: UIViewController {
    private static let filterViewHeight = DataEntry.Metric.Tokens.Filter.height
    static let addHideTokensViewHeight = DataEntry.Metric.AddHideToken.Header.height

    enum Section: Equatable {
        static func == (lhs: Section, rhs: Section) -> Bool {
            switch (lhs, rhs) {
            case (.walletSummary, .walletSummary):
                return true
            case (.filters, .filters):
                return true
            case (.testnetTokens, .testnetTokens):
                return true
            case (.search, .search):
                return true
            case (.tokens, .tokens):
                return true
            case (.collectiblePairs, .collectiblePairs):
                return true
            case (.activeWalletSession(let count1), .activeWalletSession(let count2)):
                return count1 == count2
            case (_, _):
                return false
            }
        }

        case walletSummary
        case filters
        case testnetTokens
        case search
        case tokens
        case collectiblePairs
        case activeWalletSession(count: Int)
    }

    private let tokenCollection: TokenCollection
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: NonActivityEventsDataStore
    private let analyticsCoordinator: AnalyticsCoordinator

    private (set) var viewModel: TokensViewModel {
        didSet {
            viewModel.walletConnectSessions = oldValue.walletConnectSessions
            viewModel.isSearchActive = oldValue.isSearchActive
            viewModel.filter = oldValue.filter
        }
    }
    private let sessions: ServerDictionary<WalletSession>
    private let account: Wallet
    lazy private var tableViewFilterView: ScrollableSegmentedControl = {
        let cellConfiguration = Style.ScrollableSegmentedControlCell.configuration
        let controlConfiguration = Style.ScrollableSegmentedControl.configuration
        let cells = TokensViewModel.segmentedControlTitles.map { title in
            ScrollableSegmentedControlCell(frame: .zero, title: title, configuration: cellConfiguration)
        }
        let control = ScrollableSegmentedControl(cells: cells, configuration: controlConfiguration)
        control.setSelection(cellIndex: 0)
        return control
    }()
    private let emptyTableView: EmptyTableView = {
        let view = EmptyTableView(title: "", image: R.image.activities_empty_list()!, heightAdjustment: 0)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    private var emptyTableViewHeightConstraint: NSLayoutConstraint?
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.register(FungibleTokenViewCell.self)
        tableView.register(EthTokenViewCell.self)
        tableView.register(NonFungibleTokenViewCell.self)
        tableView.register(ServerTableViewCell.self)
        tableView.register(OpenSeaNonFungibleTokenPairTableCell.self)

        tableView.registerHeaderFooterView(GeneralTableViewSectionHeader<ScrollableSegmentedControl>.self)
        tableView.registerHeaderFooterView(GeneralTableViewSectionHeader<AddHideTokensView>.self)
        tableView.registerHeaderFooterView(ActiveWalletSessionView.self)
        tableView.registerHeaderFooterView(GeneralTableViewSectionHeader<WalletSummaryView>.self)
        tableView.estimatedRowHeight = DataEntry.Metric.TableView.estimatedRowHeight
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.separatorInset = .zero

        tableView.translatesAutoresizingMaskIntoConstraints = false

        return tableView
    }()
    private lazy var tableViewRefreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        return control
    }()
    private (set) lazy var blockieImageView: BlockieImageView = .defaultBlockieImageView
    private let searchController: UISearchController
    private lazy var searchBar: DummySearchView = {
        return DummySearchView(closure: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.enterSearchMode()
        })
    }()

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
    private lazy var whereAreMyTokensView: AddHideTokensView = {
        let view = AddHideTokensView()
        view.delegate = self
        view.configure(viewModel: ShowAddHideTokensViewModel.configuredForTestnet())

        return view
    }()

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
                consoleButton.setTitleColor(Colors.black, for: .normal)
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
    private lazy var searchBarHeader: TokensViewController.ContainerView<DummySearchView> = {
        let header: TokensViewController.ContainerView<DummySearchView> = .init(subview: searchBar)
        header.useSeparatorLine = false

        return header
    }()
    private var cancellable = Set<AnyCancellable>()

    init(sessions: ServerDictionary<WalletSession>,
         account: Wallet,
         tokenCollection: TokenCollection,
         assetDefinitionStore: AssetDefinitionStore,
         eventsDataStore: NonActivityEventsDataStore,
         tokensFilter: TokensFilter,
         config: Config,
         walletConnectCoordinator: WalletConnectCoordinator,
         walletBalanceCoordinator: WalletBalanceCoordinatorType,
         analyticsCoordinator: AnalyticsCoordinator
    ) {
        self.sessions = sessions
        self.account = account
        self.tokenCollection = tokenCollection
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
        self.config = config
        self.walletConnectCoordinator = walletConnectCoordinator
        self.analyticsCoordinator = analyticsCoordinator
        walletSummarySubscription = walletBalanceCoordinator.subscribableWalletBalance(wallet: account)

        viewModel = TokensViewModel(tokensFilter: tokensFilter, tokens: [], config: config)

        searchController = UISearchController(searchResultsController: nil)

        super.init(nibName: nil, bundle: nil)

        searchController.delegate = self
        searchController.hidesNavigationBarDuringPresentation = false

        view.backgroundColor = viewModel.backgroundColor

        tableViewFilterView.addTarget(self, action: #selector(didTapSegment(_:)), for: .touchUpInside)
        tableViewFilterView.translatesAutoresizingMaskIntoConstraints = false

        consoleButton.addTarget(self, action: #selector(openConsole), for: .touchUpInside)

        view.addSubview(tableView)

        bottomConstraint = tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        keyboardChecker.constraints = [bottomConstraint]

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            bottomConstraint
        ])

        tableView.addSubview(emptyTableView)
        let heightConstraint = emptyTableView.centerYAnchor.constraint(equalTo: tableView.centerYAnchor, constant: 0)
        emptyTableViewHeightConstraint = heightConstraint
        NSLayoutConstraint.activate([
            emptyTableView.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            heightConstraint
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

        walletConnectCoordinator.sessionsSubscribable.subscribe { [weak self] value in
            guard let strongSelf = self, let sessions = value else { return }

            let viewModel = strongSelf.viewModel
            viewModel.walletConnectSessions = sessions.count
            strongSelf.viewModel = viewModel

            strongSelf.tableView.reloadData()
        }

        TokensViewController.reloadWalletSummaryView(walletSummaryView, with: walletSummarySubscription.value, config: config)
        subscriptionKey = walletSummarySubscription.subscribe { [weak walletSummaryView] balance in
            guard let view = walletSummaryView else { return }
            TokensViewController.reloadWalletSummaryView(view, with: balance, config: config)
        }
        navigationItem.largeTitleDisplayMode = .never
    }

    deinit {
        subscriptionKey.flatMap { walletSummarySubscription.unsubscribe($0) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
        tableView.addSubview(tableViewRefreshControl)

        handleTokenCollectionUpdates()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.applyTintAdjustment()
        hidesBottomBarWhenPushed = false

        fetch()
        fixNavigationBarAndStatusBarBackgroundColorForiOS13Dot1()
        keyboardChecker.viewWillAppear()
        delegate?.viewWillAppear(in: self)
        hideNavigationBarTopSeparatorLine()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        keyboardChecker.viewWillDisappear()
        showNavigationBarTopSeparatorLine()
    }

    @objc func pullToRefresh() {
        tableViewRefreshControl.beginRefreshing()
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
        configureSearchBarOnce()
    }

    private func reloadTableData() {
        tableView.reloadData()
    }

    private func reload() {
        isPromptBackupWalletViewHolderHidden = !(viewModel.shouldShowBackupPromptViewHolder && !promptBackupWalletViewHolder.subviews.isEmpty) || shouldHidePromptBackupWalletViewHolderBecauseSearchIsActive
        reloadTableData()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func refreshView(viewModel: TokensViewModel) {
        view.backgroundColor = viewModel.backgroundColor
        tableView.backgroundColor = viewModel.backgroundColor
    }

    private func handleTokenCollectionUpdates() {
        //NOTE: we don't apply .subscribe(on: DispatchQueue.main) for refresh table view immediatelly, otherwise an empty tokens view will be presented
        tokenCollection.tokensViewModel
            .sink { [weak self] viewModel in
                guard let strongSelf = self else { return }
                strongSelf.viewModel = viewModel
                strongSelf.refreshView(viewModel: viewModel)
                strongSelf.endLoading()
                strongSelf.reload()

                if strongSelf.tableViewRefreshControl.isRefreshing {
                    strongSelf.tableViewRefreshControl.endRefreshing()
                }
            }.store(in: &cancellable)
    }

    private func adjustTableViewHeaderHeightToFitContents() {
        let size = tableViewHeader.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        tableViewHeader.bounds.size.height = size.height
        tableView.tableHeaderView = tableViewHeader
    }

    private static func reloadWalletSummaryView(_ walletSummaryView: WalletSummaryView, with balance: WalletBalance?, config: Config) {
        let summary = balance.map { WalletSummary(balances: [$0]) }
        walletSummaryView.configure(viewModel: .init(summary: summary, config: config, alignment: .center))
    }

    @objc private func enterSearchMode() {
        let searchController = searchController
        navigationItem.searchController = searchController

        viewModel.isSearchActive = true
        viewModel.filter = viewModel.filter
        tableView.reloadData()

        DispatchQueue.main.async {
            searchController.isActive = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                searchController.searchBar.becomeFirstResponder()
            }
        }
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

        didSelectToken(indexPath: indexPath)
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
        case .activeWalletSession:
            return 80
        case .search, .testnetTokens:
            return TokensViewController.addHideTokensViewHeight
        case .tokens, .collectiblePairs:
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
            let header: TokensViewController.GeneralTableViewSectionHeader<ScrollableSegmentedControl> = tableView.dequeueReusableHeaderFooterView()
            header.subview = tableViewFilterView
            header.useSeparatorLine = false

            return header
        case .activeWalletSession(let count):
            let header: ActiveWalletSessionView = tableView.dequeueReusableHeaderFooterView()
            header.configure(viewModel: .init(count: count))
            header.delegate = self

            return header
        case .testnetTokens:
            let header: TokensViewController.GeneralTableViewSectionHeader<AddHideTokensView> = tableView.dequeueReusableHeaderFooterView()
            header.useSeparatorTopLine = true
            header.useSeparatorBottomLine = viewModel.isBottomSeparatorLineHiddenForTestnetHeader(section: section)
            header.subview = whereAreMyTokensView

            return header
        case .search:
            return searchBarHeader
        case .tokens, .collectiblePairs:
            return nil
        }
    }

    // UIScrollViewDelegate calls

    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        hideNavigationBarTopSeparatorLineInScrollEdgeAppearance()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        scrollView.contentOffset.y == 0 ? hideNavigationBarTopSeparatorLineInScrollEdgeAppearance() : showNavigationBarTopSeparatorLineInScrollEdgeAppearance()
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
        case .search, .testnetTokens, .walletSummary, .filters, .activeWalletSession:
            return UITableViewCell()
        case .tokens:
            switch viewModel.item(for: indexPath.row, section: indexPath.section) {
            case .rpcServer(let server):
                let cell: ServerTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: TokenListServerTableViewCellViewModel(server: server, isTopSeparatorHidden: true))

                return cell
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
        case .collectiblePairs:
            let pair = viewModel.collectiblePairs[indexPath.row]

            let cell: OpenSeaNonFungibleTokenPairTableCell = tableView.dequeueReusableCell(for: indexPath)
            cell.delegate = self

            let left: OpenSeaNonFungibleTokenViewCellViewModel = .init(token: pair.left)
            let right: OpenSeaNonFungibleTokenViewCellViewModel? = pair.right.flatMap { token in
                return OpenSeaNonFungibleTokenViewCellViewModel(token: token)
            }

            cell.configure(viewModel: .init(leftViewModel: left, rightViewModel: right))

            return cell
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return viewModel.cellHeight(for: indexPath)
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? OpenSeaNonFungibleTokenPairTableCell else { return }

        cell.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: .greatestFiniteMagnitude)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let rowCount = viewModel.numberOfItems(for: section)
        let mode = viewModel.sections[section]
        if mode == .tokens || mode == .collectiblePairs {
            handleTokensCountChange(rows: rowCount)
        }
        return rowCount
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        viewModel.sections.count
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        switch viewModel.sections[indexPath.section] {
        case .collectiblePairs, .testnetTokens, .search, .walletSummary, .filters, .activeWalletSession:
            return nil
        case .tokens:
            return trailingSwipeActionsConfiguration(forRowAt: indexPath)
        }
    }

    private func trailingSwipeActionsConfiguration(forRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let item = viewModel.item(for: indexPath.row, section: indexPath.section)
        guard item.canDelete else { return nil }
        switch item {
        case .rpcServer:
            return nil
        case .tokenObject(let token):
            let title = R.string.localizable.walletsHideTokenTitle()
            let hideAction = UIContextualAction(style: .destructive, title: title) { [weak self] (_, _, completion) in
                guard let strongSelf = self else { return }

                let deletedIndexPathArray = strongSelf.viewModel.indexPathArrayForDeletingAt(indexPath: indexPath)
                strongSelf.delegate?.didHide(token: token, in: strongSelf)

                let didHideToken = strongSelf.viewModel.markTokenHidden(token: token)
                if didHideToken {
                    strongSelf.tableView.deleteRows(at: deletedIndexPathArray, with: .automatic)
                } else {
                    strongSelf.reloadTableData()
                }

                completion(didHideToken)
            }

            hideAction.backgroundColor = R.color.danger()
            hideAction.image = R.image.hideToken()
            let configuration = UISwipeActionsConfiguration(actions: [hideAction])
            configuration.performsFirstActionWithFullSwipe = true

            return configuration
        }
    }

    private func handleTokensCountChange(rows: Int) {
        let isEmpty = rows == 0
        let title: String
        switch viewModel.filter {
        case .assetsOnly:
            title = R.string.localizable.emptyTableViewWalletTitle(R.string.localizable.aWalletContentsFilterAssetsOnlyTitle())
        case .collectiblesOnly:
            title = R.string.localizable.emptyTableViewWalletTitle(R.string.localizable.aWalletContentsFilterCollectiblesOnlyTitle())
        case .currencyOnly:
            title = R.string.localizable.emptyTableViewWalletTitle(R.string.localizable.aWalletContentsFilterCurrencyOnlyTitle())
        case .keyword:
            title = R.string.localizable.emptyTableViewSearchTitle()
        case .all:
            title = R.string.localizable.emptyTableViewWalletTitle(R.string.localizable.emptyTableViewAllTitle())
        default:
            title = ""
        }
        if isEmpty {
            if let height = tableHeight() {
                emptyTableViewHeightConstraint?.constant = height/2.0
            } else {
                emptyTableViewHeightConstraint?.constant = 0
            }
            emptyTableView.title = title
        }
        emptyTableView.isHidden = !isEmpty
    }

    private func tableHeight() -> CGFloat? {
        guard let delegate = tableView.delegate else { return nil }
        let sectionCount = viewModel.sections.count
        var height: CGFloat = 0
        for sectionIndex in 0..<sectionCount {
            let rows = viewModel.numberOfItems(for: sectionIndex)
            for rowIndex in 0..<rows {
                height += (delegate.tableView?(tableView, heightForRowAt: IndexPath(row: rowIndex, section: sectionIndex))) ?? 0
            }
            height += (delegate.tableView?(tableView, heightForHeaderInSection: sectionIndex)) ?? 0
            height += (delegate.tableView?(tableView, heightForFooterInSection: sectionIndex)) ?? 0
        }
        return height
    }
}

extension TokensViewController: AddHideTokensViewDelegate {

    func view(_ view: AddHideTokensView, didSelectAddHideTokensButton sender: UIButton) {
        delegate?.whereAreMyTokensSelected(in: self)
    }
}

extension TokensViewController {
    @objc func didTapSegment(_ control: ScrollableSegmentedControl) {
        guard let filter = viewModel.convertSegmentedControlSelectionToFilter(control.selectedSegment) else { return }
        apply(filter: filter, withSegmentAtSelection: control.selectedSegment)
    }

    private func apply(filter: WalletFilter, withSegmentAtSelection selection: ControlSelection?) {
        let previousFilter = viewModel.filter
        viewModel.filter = filter
        reload()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            //Important to update the segmented control (and hence add the segmented control back to the table) after they have been re-added to the table header through the table reload. Otherwise adding to the table header will break the animation for segmented control
            if let selection = selection, case let ControlSelection.selected(index) = selection {
                self.tableViewFilterView.setSelection(cellIndex: Int(index))
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

extension TokensViewController: UISearchControllerDelegate {

    func didDismissSearchController(_ searchController: UISearchController) {
        guard viewModel.isSearchActive else { return }

        navigationItem.searchController = nil

        viewModel.isSearchActive = false
        viewModel.filter = viewModel.filter

        tableView.reloadData()
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
        tableViewFilterView.unselect()
        apply(filter: .keyword(keyword), withSegmentAtSelection: nil)
    }

    private func setDefaultFilter() {
        apply(filter: .all, withSegmentAtSelection: .selected(0))
    }
}

fileprivate class DummySearchView: UIView {

    private let searchBar: UISearchBar = {
        let searchBar: UISearchBar = UISearchBar(frame: .init(x: 0, y: 0, width: 100, height: 50))
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.isUserInteractionEnabled = false
        UISearchBar.configure(searchBar: searchBar)

        return searchBar
    }()

    private var overlayView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = true
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false

        return view
    }()

    init(closure: @escaping () -> Void) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(searchBar)
        addSubview(overlayView)

        NSLayoutConstraint.activate(searchBar.anchorsConstraint(to: self) + overlayView.anchorsConstraint(to: self))

        UITapGestureRecognizer(addToView: overlayView, closure: closure)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension TokensViewController: OpenSeaNonFungibleTokenPairTableCellDelegate {

    private func didSelectToken(indexPath: IndexPath) {
        let selection = viewModel.item(for: indexPath.row, section: indexPath.section)

        switch (viewModel.sections[indexPath.section], selection) {
        case (.tokens, .tokenObject(let token)):
            delegate?.didSelect(token: token, in: self)
        case (_, _):
            break
        }
    }

    func didSelect(cell: OpenSeaNonFungibleTokenPairTableCell, indexPath: IndexPath, isLeftCardSelected: Bool) {
        switch viewModel.sections[indexPath.section] {
        case .collectiblePairs:
            let pair = viewModel.collectiblePairs[indexPath.row]
            guard let token: TokenObject = isLeftCardSelected ? pair.left : pair.right else { return }
            delegate?.didSelect(token: token, in: self)
        case .tokens, .testnetTokens, .activeWalletSession, .filters, .search, .walletSummary:
            break
        }
    }
}

///Support searching/filtering tokens with keywords. This extension is set up so it's easier to copy and paste this functionality elsewhere
extension TokensViewController {
    private func makeSwitchToAnotherTabWorkWhileFiltering() {
        definesPresentationContext = true
    }

    private func wireUpSearchController() {
        searchController.searchResultsUpdater = self
    }

    private func fixNavigationBarAndStatusBarBackgroundColorForiOS13Dot1() {
        view.superview?.backgroundColor = viewModel.backgroundColor
    }

    private func setupFilteringWithKeyword() {
        navigationItem.hidesSearchBarWhenScrolling = false
        wireUpSearchController()
        TokensViewController.functional.fixTableViewBackgroundColor(tableView: tableView, backgroundColor: viewModel.backgroundColor)
        doNotDimTableViewToReuseTableForFilteringResult()
        makeSwitchToAnotherTabWorkWhileFiltering()
    }

    private func doNotDimTableViewToReuseTableForFilteringResult() {
        searchController.obscuresBackgroundDuringPresentation = false
    }

    //Makes a difference where this is called from. Can't be too early
    private func configureSearchBarOnce() {
        guard !isSearchBarConfigured else { return }
        isSearchBarConfigured = true
        UISearchBar.configure(searchBar: searchController.searchBar)
    }
}

//MARK: Search
extension TokensViewController {
    override var keyCommands: [UIKeyCommand]? {
        return [UIKeyCommand(input: "f", modifierFlags: .command, action: #selector(enterSearchMode), discoverabilityTitle: "Filter")]
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

extension UISearchBar {
    static func configure(searchBar: UISearchBar, backgroundColor: UIColor = Colors.appBackground) {
        if let placeholderLabel = searchBar.firstSubview(ofType: UILabel.self) {
            placeholderLabel.textColor = Colors.lightGray
        }
        if let textField = searchBar.firstSubview(ofType: UITextField.self) {
            textField.textColor = Colors.appText
            if let imageView = textField.leftView as? UIImageView {
                imageView.image = imageView.image?.withRenderingMode(.alwaysTemplate)
                imageView.tintColor = Colors.appText
            }
        }
        //Hack to hide the horizontal separator below the search bar
        searchBar.superview?.firstSubview(ofType: UIImageView.self)?.isHidden = true
        //Remove border line
        searchBar.layer.borderWidth = 1
        searchBar.layer.borderColor = UIColor.clear.cgColor
        searchBar.backgroundImage = UIImage()
        searchBar.placeholder = R.string.localizable.tokensSearchbarPlaceholder()
        searchBar.backgroundColor = backgroundColor
    }
}
