// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import StatefulViewController
import Result

protocol TokensViewControllerDelegate: class {
    func didPressAddToken( in viewController: UIViewController)
    func didSelect(token: TokenObject, in viewController: UIViewController)
    func didDelete(token: TokenObject, in viewController: UIViewController)
    func didTapOpenConsole(in viewController: UIViewController)
}

class TokensViewController: UIViewController {
    private static let filterViewHeight = CGFloat(44)

    private let tokenCollection: TokenCollection
    private let assetDefinitionStore: AssetDefinitionStore

    private var viewModel: TokensViewModel {
        didSet {
            viewModel.filter = oldValue.filter
            refreshView(viewModel: viewModel)
        }
    }
    private let sessions: ServerDictionary<WalletSession>
    private let account: Wallet
    private let tableViewFilterView = WalletFilterView()
    private let collectiblesCollectionViewFilterView = WalletFilterView()
    private var importWalletView: UIView?
    private var importWalletLayer = CAShapeLayer()
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
         assetDefinitionStore: AssetDefinitionStore
    ) {
		self.sessions = sessions
        self.account = account
        self.tokenCollection = tokenCollection
        self.assetDefinitionStore = assetDefinitionStore
        self.viewModel = TokensViewModel(tokens: [], tickers: .init())
        tableView = UITableView(frame: .zero, style: .plain)
        searchController = UISearchController(searchResultsController: nil)

        super.init(nibName: nil, bundle: nil)
        handleTokenCollectionUpdates()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addToken))

        view.backgroundColor = Colors.appBackground

        tableViewFilterView.delegate = self
        tableViewFilterView.translatesAutoresizingMaskIntoConstraints = false

        collectiblesCollectionViewFilterView.delegate = self
        collectiblesCollectionViewFilterView.translatesAutoresizingMaskIntoConstraints = false

        consoleButton.addTarget(self, action: #selector(openConsole), for: .touchUpInside)

        tableView.register(FungibleTokenViewCell.self, forCellReuseIdentifier: FungibleTokenViewCell.identifier)
        tableView.register(EthTokenViewCell.self, forCellReuseIdentifier: EthTokenViewCell.identifier)
        tableView.register(NonFungibleTokenViewCell.self, forCellReuseIdentifier: NonFungibleTokenViewCell.identifier)
        tableView.estimatedRowHeight = 0
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = Colors.appBackground
        tableViewRefreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        tableView.addSubview(tableViewRefreshControl)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        collectiblesCollectionView.backgroundColor = Colors.appBackground
        collectiblesCollectionView.translatesAutoresizingMaskIntoConstraints = false
        collectiblesCollectionView.alwaysBounceVertical = true
        collectiblesCollectionView.register(OpenSeaNonFungibleTokenViewCell.self, forCellWithReuseIdentifier: OpenSeaNonFungibleTokenViewCell.identifier)
        collectiblesCollectionView.register(CollectiblesCollectionViewHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: CollectiblesCollectionViewHeader.reuseIdentifier)
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
        fetch()
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
        if let importWalletView = importWalletView {
            importWalletLayer.frame = importWalletView.bounds
            importWalletLayer.path = createImportWalletImagePath().cgPath
        }
        //viewDidLayoutSubviews() is called many times
        configureSearchBarOnce()
    }

    private func reload() {
        isPromptBackupWalletViewHolderHidden = !(viewModel.shouldShowBackupPromptViewHolder && !promptBackupWalletViewHolder.subviews.isEmpty) || shouldHidePromptBackupWalletViewHolderBecauseSearchIsActive
        collectiblesCollectionView.isHidden = !viewModel.shouldShowCollectiblesCollectionView
        tableView.reloadData()
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
            hideImportWalletImage()
        } else {
            showImportWalletImage()
        }
    }

    private func hideImportWalletImage() {
        importWalletView?.isHidden = true
    }

    private func showImportWalletImage() {
        guard !searchController.isActive else { return }
        if let importWalletView = importWalletView {
            importWalletView.isHidden = false
            return
        }
        importWalletView = UIView()
        if let importWalletView = importWalletView {
            view.addSubview(importWalletView)

            let imageView = UIImageView(image: R.image.wallet_import())

            importWalletLayer.path = createImportWalletImagePath().cgPath
            importWalletLayer.lineDashPattern = [5, 5]
            importWalletLayer.strokeColor = UIColor.white.cgColor
            importWalletLayer.fillColor = UIColor.clear.cgColor
            importWalletView.layer.addSublayer(importWalletLayer)

            let label = UILabel()
            label.textColor = .white
            label.text = R.string.localizable.aWalletImportWalletTitle()

            let stackView = [
                imageView,
                label,
            ].asStackView(axis: .vertical, spacing: 10, alignment: .center)
            stackView.translatesAutoresizingMaskIntoConstraints = false
            importWalletView.addSubview(stackView)

            let sideMargin = CGFloat(7)
            importWalletView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                importWalletView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
                importWalletView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sideMargin),
                importWalletView.topAnchor.constraint(equalTo: view.topAnchor, constant: 52),
                importWalletView.heightAnchor.constraint(equalToConstant: 138),

                stackView.centerXAnchor.constraint(equalTo: importWalletView.centerXAnchor),
                stackView.centerYAnchor.constraint(equalTo: importWalletView.centerYAnchor),
            ])
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func refreshView(viewModel: TokensViewModel) {
        title = viewModel.title
        view.backgroundColor = viewModel.backgroundColor
    }

    @objc func addToken() {
        delegate?.didPressAddToken(in: self)
    }

    private func createImportWalletImagePath() -> UIBezierPath {
        if let importWalletView = importWalletView {
            let path = UIBezierPath(roundedRect: importWalletView.bounds, cornerRadius: 20)
            return path
        } else {
            return UIBezierPath()
        }
    }

    //Reloading the collectibles tab is very obvious visually, with the flashing images even if there are no changes. So we used this to check if the list of collectibles have changed, if not, don't refresh. We could have used a library that tracks diff, but that is overkill and one more dependency
    private func contractsForCollectiblesFromViewModel() -> [AlphaWallet.Address] {
        var contractsForCollectibles = [AlphaWallet.Address]()
        for i in (0..<viewModel.numberOfItems(for: 0)) {
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

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return viewModel.canDelete(for: indexPath.row, section: indexPath.section)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            delegate?.didDelete(token: viewModel.item(for: indexPath.row, section: indexPath.section), in: self)
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let token = viewModel.item(for: indexPath.row, section: indexPath.section)
        let server = token.server
        let session = sessions[server]

        switch token.type {
        case .nativeCryptocurrency:
            let cellViewModel = EthTokenViewCellViewModel(
                    token: token,
                    ticker: viewModel.ticker(for: token),
                    currencyAmount: session.balanceCoordinator.viewModel.currencyAmount,
                    currencyAmountWithoutSymbol: session.balanceCoordinator.viewModel.currencyAmountWithoutSymbol,
                    server: server,
                    assetDefinitionStore: assetDefinitionStore
            )
            return cellViewModel.cellHeight
        case .erc20:
            let cellViewModel = FungibleTokenViewCellViewModel(token: token, server: server, assetDefinitionStore: assetDefinitionStore)
            return cellViewModel.cellHeight
        case .erc721:
            let cellViewModel = NonFungibleTokenViewCellViewModel(token: token, server: server, assetDefinitionStore: assetDefinitionStore)
            return cellViewModel.cellHeight
        case .erc875:
            let cellViewModel = NonFungibleTokenViewCellViewModel(token: token, server: server, assetDefinitionStore: assetDefinitionStore)
            return cellViewModel.cellHeight
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return TokensViewController.filterViewHeight
    }


    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: TableViewSectionHeader.reuseIdentifier) as? TableViewSectionHeader ?? TableViewSectionHeader(reuseIdentifier: TableViewSectionHeader.reuseIdentifier)
        header.filterView = tableViewFilterView
        return header
    }
}

extension TokensViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let token = viewModel.item(for: indexPath.row, section: indexPath.section)
        let server = token.server
        let session = sessions[server]
        switch token.type {
        case .nativeCryptocurrency:
            let cell = tableView.dequeueReusableCell(withIdentifier: EthTokenViewCell.identifier, for: indexPath) as! EthTokenViewCell
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
            let cell = tableView.dequeueReusableCell(withIdentifier: FungibleTokenViewCell.identifier, for: indexPath) as! FungibleTokenViewCell
            cell.configure(viewModel: .init(token: token, server: server, assetDefinitionStore: assetDefinitionStore))
            return cell
        case .erc721:
            let cell = tableView.dequeueReusableCell(withIdentifier: NonFungibleTokenViewCell.identifier, for: indexPath) as! NonFungibleTokenViewCell
            cell.configure(viewModel: .init(token: token, server: server, assetDefinitionStore: assetDefinitionStore))
            return cell
        case .erc875:
            let cell = tableView.dequeueReusableCell(withIdentifier: NonFungibleTokenViewCell.identifier, for: indexPath) as! NonFungibleTokenViewCell
            cell.configure(viewModel: .init(token: token, server: server, assetDefinitionStore: assetDefinitionStore))
            return cell
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfItems(for: section)
    }
}

extension TokensViewController: WalletFilterViewDelegate {
    func didPressWalletFilter(filter: WalletFilter, in filterView: WalletFilterView) {
        let previousFilter = viewModel.filter
        if filterView == tableViewFilterView {
            collectiblesCollectionViewFilterView.filter = filter
        } else if filterView == collectiblesCollectionViewFilterView {
            tableViewFilterView.filter = filter
        }
        viewModel.filter = filter
        reload()
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
        return viewModel.numberOfItems(for: section)
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let token = viewModel.item(for: indexPath.row, section: indexPath.section)
        let server = token.server
        let session = sessions[server]
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: OpenSeaNonFungibleTokenViewCell.identifier, for: indexPath) as! OpenSeaNonFungibleTokenViewCell
        cell.configure(viewModel: .init(config: session.config, token: token, forWallet: account, assetDefinitionStore: assetDefinitionStore))
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: CollectiblesCollectionViewHeader.reuseIdentifier, for: indexPath) as! CollectiblesCollectionViewHeader
        header.filterView = collectiblesCollectionViewFilterView
        return header
    }
}

extension TokensViewController: UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectiblesCollectionView.deselectItem(at: indexPath, animated: true)
        let token = viewModel.item(for: indexPath.item, section: indexPath.section)
        delegate?.didSelect(token: token, in: self)
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
            case .keyword(let keyword):
                //Handle when user taps clear button
                if !keyword.isEmpty {
                    updateResults(withKeyword: "")
                }
            }
            return
        }
        let keyword = searchController.searchBar.text ?? ""
        updateResults(withKeyword: keyword)
    }

    private func updateResults(withKeyword keyword: String) {
        tableViewFilterView.searchFor(keyword: keyword)
        collectiblesCollectionViewFilterView.searchFor(keyword: keyword)
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
        v.backgroundColor = Colors.appBackground
        tableView.backgroundView = v
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
            textField.textColor = Colors.appWhite
            if let imageView = textField.leftView as? UIImageView {
                imageView.image = imageView.image?.withRenderingMode(.alwaysTemplate)
                imageView.tintColor = Colors.lightGray
            }
        }
        //Hack to hide the horizontal separator below the search bar
        searchController.searchBar.superview?.firstSubview(ofType: UIImageView.self)?.isHidden = true
    }
}
