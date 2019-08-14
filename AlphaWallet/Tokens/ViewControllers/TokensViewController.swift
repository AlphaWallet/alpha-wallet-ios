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
	private let filterView = WalletFilterView()
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
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }()
    private var currentCollectiblesContractsDisplayed = [AlphaWallet.Address]()
    private let searchController: UISearchController
    private let consoleButton = UIButton(type: .system)

    weak var delegate: TokensViewControllerDelegate?
    //TODO The name "bad" isn't correct. Because it includes "conflicts" too
    var listOfBadTokenScriptFiles: [TokenScriptFileIndices.FileName] = .init() {
        didSet {
            if listOfBadTokenScriptFiles.isEmpty {
                consoleButton.isHidden = true
            } else {
                consoleButton.isHidden = false
                consoleButton.titleLabel?.font = Fonts.light(size: 22)!
                consoleButton.setTitleColor(Colors.appWhite, for: .normal)
                consoleButton.setTitle(R.string.localizable.tokenScriptShowErrors(), for: .normal)
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

        filterView.delegate = self
        filterView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterView)

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

        let bodyStackView = [
            consoleButton,
            tableView,
        ].asStackView(axis: .vertical)
        bodyStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bodyStackView)

        collectiblesCollectionView.backgroundColor = Colors.appBackground
        collectiblesCollectionView.translatesAutoresizingMaskIntoConstraints = false
        collectiblesCollectionView.alwaysBounceVertical = true
        collectiblesCollectionView.register(OpenSeaNonFungibleTokenViewCell.self, forCellWithReuseIdentifier: OpenSeaNonFungibleTokenViewCell.identifier)
        collectiblesCollectionView.dataSource = self
        collectiblesCollectionView.isHidden = true
        collectiblesCollectionView.delegate = self
        collectiblesCollectionViewRefreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        collectiblesCollectionView.refreshControl = collectiblesCollectionViewRefreshControl
        view.addSubview(collectiblesCollectionView)

        NSLayoutConstraint.activate([
            filterView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filterView.topAnchor.constraint(equalTo: view.topAnchor),
            filterView.bottomAnchor.constraint(equalTo: bodyStackView.topAnchor, constant: -7),

            bodyStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bodyStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bodyStackView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            bodyStackView.leadingAnchor.constraint(equalTo: collectiblesCollectionView.leadingAnchor),
            bodyStackView.trailingAnchor.constraint(equalTo: collectiblesCollectionView.trailingAnchor),
            bodyStackView.topAnchor.constraint(equalTo: collectiblesCollectionView.topAnchor),
            bodyStackView.bottomAnchor.constraint(equalTo: collectiblesCollectionView.bottomAnchor),
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
    }

    private func reload() {
        tableView.isHidden = !viewModel.shouldShowTable
        collectiblesCollectionView.isHidden = !viewModel.shouldShowCollectiblesCollectionView
        if viewModel.hasContent {
            if viewModel.shouldShowTable {
                tableView.reloadData()
            }
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
        viewModel.filter = filter
        reload()
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
}

extension TokensViewController: UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectiblesCollectionView.deselectItem(at: indexPath, animated: true)
        let token = viewModel.item(for: indexPath.item, section: indexPath.section)
        delegate?.didSelect(token: token, in: self)
    }
}

extension TokensViewController: UISearchResultsUpdating {
    public func updateSearchResults(for searchController: UISearchController) {
        let keyword = searchController.searchBar.text ?? ""
        filterView.searchFor(keyword: keyword)
    }
}

///Support searching/filtering tokens with keywords. This extension is set up so it's easier to copy and paste this functionality elsewhere
extension TokensViewController {
    private func hideSearchBarForInitialUse() {
        tableView.contentOffset = CGPoint(x: 0, y: searchController.searchBar.frame.size.height)
    }

    private func makeSwitchToAnotherTabWorkWhileFiltering() {
        definesPresentationContext = true
    }

    private func removeSearchBarBorderForiOS10() {
        searchController.searchBar.setBackgroundImage(UIImage(color: Colors.appBackground), for: .any, barMetrics: .default)
    }

    private func doNotDimTableViewToReuseTableForFilteringResult() {
        searchController.dimsBackgroundDuringPresentation = false
    }

    private func wireUpSearchController() {
        searchController.searchResultsUpdater = self
        //Can't get `navigationItem.searchController = searchController` to work correctly with iOS 12 (probably 11 too). It wouldn't work with iOS 10 anyway.
        tableView.tableHeaderView = searchController.searchBar
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
        removeSearchBarBorderForiOS10()
        makeSwitchToAnotherTabWorkWhileFiltering()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.hideSearchBarForInitialUse()
        }
    }
}
