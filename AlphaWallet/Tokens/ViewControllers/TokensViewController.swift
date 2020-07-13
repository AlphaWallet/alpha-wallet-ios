// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Result
import StatefulViewController

protocol TokensViewControllerDelegate: class {
    func didPressAddHideTokens(viewModel: TokensViewModel)
    func didSelect(token: TokenObject, in viewController: UIViewController)
    func didHide(token: TokenObject, in viewController: UIViewController)
    func didTapOpenConsole(in viewController: UIViewController)
}

class TokensViewController: UIViewController {
    private static let filterViewHeight = CGFloat(50)

    private enum Section {
        case addHideToken
        case tokens
    }

    private let tokenCollection: TokenCollection
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: EventsDataStoreProtocol
    private let sections: [Section] = [.addHideToken, .tokens]

    private var viewModel: TokensViewModel {
        didSet {
            viewModel.filter = oldValue.filter
            refreshView(viewModel: viewModel)
        }
    }
    private let sessions: ServerDictionary<WalletSession>
    private let account: Wallet
    lazy private var tableViewFilterView = SegmentedControl(titles: TokensViewModel.segmentedControlTitles)
    lazy private var collectiblesCollectionViewFilterView = SegmentedControl(titles: TokensViewModel.segmentedControlTitles)
    private let tableView: UITableView
    private let tableViewRefreshControl = UIRefreshControl()
    private let collectiblesCollectionViewRefreshControl = UIRefreshControl()
    private let collectiblesCollectionView = { () -> UICollectionView in
        let layout = UICollectionViewFlowLayout()
        let numberOfColumns = CGFloat(3)
        let dimension = (UIScreen.main.bounds.size.width / numberOfColumns).rounded(.down)
        let heightForLabel = CGFloat(18)
        layout.itemSize = CGSize(width: dimension, height: dimension + heightForLabel)
        layout.minimumInteritemSpacing = 0
        layout.headerReferenceSize = .init(width: 100, height: TokensViewController.filterViewHeight)
        layout.sectionHeadersPinToVisibleBounds = true
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }()
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
    private let hideTokenWidth: CGFloat = 170

    weak var delegate: TokensViewControllerDelegate?
    //TODO The name "bad" isn't correct. Because it includes "conflicts" too
    var listOfBadTokenScriptFiles: [TokenScriptFileIndices.FileName] = .init() {
        didSet {
            if listOfBadTokenScriptFiles.isEmpty {
                isConsoleButtonHidden = true
            } else {
                consoleButton.titleLabel?.font = Fonts.light(size: 22)!
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

    init(sessions: ServerDictionary<WalletSession>,
         account: Wallet,
         tokenCollection: TokenCollection,
         assetDefinitionStore: AssetDefinitionStore,
         eventsDataStore: EventsDataStoreProtocol,
         filterTokensCoordinator: FilterTokensCoordinator
    ) {
        self.sessions = sessions
        self.account = account
        self.tokenCollection = tokenCollection
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
        self.viewModel = TokensViewModel(filterTokensCoordinator: filterTokensCoordinator, tokens: [], tickers: .init())
        tableView = UITableView(frame: .zero, style: .plain)
        searchController = UISearchController(searchResultsController: nil)

        super.init(nibName: nil, bundle: nil)
        handleTokenCollectionUpdates()

        hidesBottomBarWhenPushed = true
        view.backgroundColor = viewModel.backgroundColor

        tableViewFilterView.delegate = self
        tableViewFilterView.translatesAutoresizingMaskIntoConstraints = false

        collectiblesCollectionViewFilterView.delegate = self
        collectiblesCollectionViewFilterView.translatesAutoresizingMaskIntoConstraints = false

        consoleButton.addTarget(self, action: #selector(openConsole), for: .touchUpInside)

        tableView.register(AddHideTokensCell.self)
        tableView.register(FungibleTokenViewCell.self)
        tableView.register(EthTokenViewCell.self)
        tableView.register(NonFungibleTokenViewCell.self)
        tableView.registerHeaderFooterView(TableViewSectionHeader.self)
//        tableView.estimatedRowHeight = 0
        tableView.estimatedRowHeight = 100
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.separatorInset = .zero

        tableViewRefreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        tableView.addSubview(tableViewRefreshControl)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        collectiblesCollectionView.backgroundColor = viewModel.backgroundColor
        collectiblesCollectionView.translatesAutoresizingMaskIntoConstraints = false
        collectiblesCollectionView.alwaysBounceVertical = true
        collectiblesCollectionView.register(OpenSeaNonFungibleTokenViewCell.self)
        collectiblesCollectionView.registerSupplementaryView(CollectiblesCollectionViewHeader.self, of: UICollectionView.elementKindSectionHeader)
        collectiblesCollectionView.dataSource = self
        collectiblesCollectionView.isHidden = true
        collectiblesCollectionView.delegate = self
        collectiblesCollectionViewRefreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        collectiblesCollectionView.refreshControl = collectiblesCollectionViewRefreshControl
        view.addSubview(collectiblesCollectionView)

        NSLayoutConstraint.activate([
            tableView.anchorsConstraint(to: view),
            tableView.anchorsConstraint(to: collectiblesCollectionView),
        ])
        errorView = ErrorView(onRetry: { [weak self] in
            self?.startLoading()
            self?.tokenCollection.fetch()
        })
        loadingView = LoadingView()
        emptyView = EmptyView(
            title: R.string.localizable.emptyViewNoTokensLabelTitle(),
            onRetry: { [weak self] in
                self?.startLoading()
                self?.tokenCollection.fetch()
        })
        refreshView(viewModel: viewModel)

        setupFilteringWithKeyword()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.applyTintAdjustment()
        navigationController?.navigationBar.prefersLargeTitles = false
        hidesBottomBarWhenPushed = false
        
        fetch()
        fixNavigationBarAndStatusBarBackgroundColorForiOS13Dot1()
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
        configureSearchBarOnce()
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
        fatalError("init(coder:) has not been implemented")
    }

    func refreshView(viewModel: TokensViewModel) {
        title = viewModel.title
        view.backgroundColor = viewModel.backgroundColor
        tableView.backgroundColor = viewModel.backgroundColor
    }

    //Reloading the collectibles tab is very obvious visually, with the flashing images even if there are no changes. So we used this to check if the list of collectibles have changed, if not, don't refresh. We could have used a library that tracks diff, but that is overkill and one more dependency
    private func contractsForCollectiblesFromViewModel() -> [AlphaWallet.Address] {
        var contractsForCollectibles = [AlphaWallet.Address]()
        for i in (0..<viewModel.numberOfItems()) {
            let token = viewModel.item(for: i, section: 0)
            contractsForCollectibles.append(token.contractAddress)
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
        let token = viewModel.item(for: indexPath.row, section: indexPath.section)
        delegate?.didSelect(token: token, in: self)
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard section == 0 else { return 0 }
        return TokensViewController.filterViewHeight
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section == 0 else { return nil }
        let header: TableViewSectionHeader = tableView.dequeueReusableHeaderFooterView()
        header.filterView = tableViewFilterView

        return header
    }
}

extension TokensViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = sections[indexPath.section]
        switch section {
        case .addHideToken:
            return addHideTokenCell(forIndexPath: indexPath)
        case .tokens:
            return tokenCell(forIndexPath: indexPath)
        }
    }

    private func addHideTokenCell(forIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell: AddHideTokensCell = tableView.dequeueReusableCell(for: indexPath)
        cell.delegate = self
        cell.configure()
        return cell
    }

    private func tokenCell(forIndexPath indexPath: IndexPath) -> UITableViewCell {
        let token = viewModel.item(for: indexPath.row, section: indexPath.section)
        let server = token.server
        let session = sessions[server]
        switch token.type {
        case .nativeCryptocurrency:
            let cell: EthTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(
                    viewModel: .init(
                            token: token,
                            ticker: viewModel.ticker(for: token),
                            currencyAmount: session.balanceCoordinator.viewModel.currencyAmount,
                            currencyAmountWithoutSymbol: session.balanceCoordinator.viewModel.currencyAmountWithoutSymbol,
                            server: server,
                            assetDefinitionStore: assetDefinitionStore
                    )
            )
            return cell
        case .erc20:
            let cell: FungibleTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: .init(token: token, server: server, assetDefinitionStore: assetDefinitionStore))
            return cell
        case .erc721, .erc721ForTickets:
            let cell: NonFungibleTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: .init(token: token, server: server, assetDefinitionStore: assetDefinitionStore))
            return cell
        case .erc875:
            let cell: NonFungibleTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: .init(token: token, server: server, assetDefinitionStore: assetDefinitionStore))
            return cell
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = sections[section]
        switch section {
        case .addHideToken:
            return 1
        case .tokens:
            return viewModel.numberOfItems()
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let section = sections[indexPath.section]
        switch section {
        case .addHideToken:
            return nil
        case .tokens:
            return trailingSwipeActionsConfiguration(forRowAt: indexPath)
        }
    }

    private func trailingSwipeActionsConfiguration(forRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let title = R.string.localizable.walletsHideTokenTitle()
        let hideAction = UIContextualAction(style: .destructive, title: title) { [weak self] (_, _, completionHandler) in
            guard let strongSelf = self else { return }
            let token = strongSelf.viewModel.item(for: indexPath.row, section: indexPath.section)
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
            case .all, .currencyOnly, .assetsOnly, .collectiblesOnly:
                searchController.isActive = false
            case .keyword:
                break
            }
        }
    }
}

extension TokensViewController: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        //Defensive check to make sure we don't return the wrong count. iOS might decide to load (the first time especially) the collection view at some point even if we don't switch to it, thus getting the wrong count and then at some point asking for a cell for those non-existent rows/items. E.g 10 tokens total, only 3 are collectibles and asked for the 6th cell
        switch viewModel.filter {
        case .collectiblesOnly:
            return viewModel.numberOfItems()
        case .all, .currencyOnly, .assetsOnly, .keyword:
            return 0
        }
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let token = viewModel.item(for: indexPath.row, section: indexPath.section)
        let server = token.server
        let session = sessions[server]
        let cell: OpenSeaNonFungibleTokenViewCell = collectionView.dequeueReusableCell(for: indexPath)
        cell.configure(viewModel: .init(config: session.config, token: token, forWallet: account, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore))
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header: CollectiblesCollectionViewHeader = collectionView.dequeueReusableSupplementaryView(ofKind: kind, for: indexPath)
        header.filterView = collectiblesCollectionViewFilterView
        return header
    }
}

extension TokensViewController: UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
////        collectiblesCollectionView.deselectItem(at: indexPath, animated: true)
////        let token = viewModel.item(for: indexPath.item, section: indexPath.section)
////        delegate?.didSelect(token: token, in: self)
    }
}

extension TokensViewController: UISearchResultsUpdating {
    //At least on iOS 13 beta on a device. updateSearchResults(for:) is called when we set `searchController.isActive = false` to dismiss search (because user tapped on a filter), but the value of `searchController.isActive` remains `false` during the call, hence the async.
    //This behavior is not observed in iOS 12, simulator
    public func updateSearchResults(for searchController: UISearchController) {
        DispatchQueue.main.async {
            self.processSearchWithKeywords()
        }
    }

    private func processSearchWithKeywords() {
        if searchController.isActive {
            shouldHidePromptBackupWalletViewHolderBecauseSearchIsActive = true
        } else {
            shouldHidePromptBackupWalletViewHolderBecauseSearchIsActive = false
        }
        guard searchController.isActive else {
            switch viewModel.filter {
            case .all, .currencyOnly, .assetsOnly, .collectiblesOnly:
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

    private func fixTableViewBackgroundColor() {
        let v = UIView()
        v.backgroundColor = viewModel.backgroundColor
        tableView.backgroundView?.backgroundColor = viewModel.backgroundColor
        tableView.backgroundView = v
    }

    private func fixNavigationBarAndStatusBarBackgroundColorForiOS13Dot1() {
        view.superview?.backgroundColor = viewModel.backgroundColor
    }

    private func setupFilteringWithKeyword() {
        wireUpSearchController()
        fixTableViewBackgroundColor()
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
    }
}

extension TokensViewController: ShowAddHideTokensViewDelegate {
    func view(_ view: ShowAddHideTokensView, didSelectAddHideTokensButton sender: UIButton) {
        delegate?.didPressAddHideTokens(viewModel: viewModel)
    }
}
