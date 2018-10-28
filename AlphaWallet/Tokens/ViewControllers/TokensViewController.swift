// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import StatefulViewController
import Result

protocol TokensViewControllerDelegate: class {
    func didPressAddToken( in viewController: UIViewController)
    func didSelect(token: TokenObject, in viewController: UIViewController)
    func didDelete(token: TokenObject, in viewController: UIViewController)
}

class TokensViewController: UIViewController {
    private let dataStore: TokensDataStore

    private var viewModel: TokensViewModel {
        didSet {
            viewModel.filter = oldValue.filter
            refreshView(viewModel: viewModel)
        }
    }
    private let session: WalletSession
    private let account: Wallet
	private let filterView = WalletFilterView()
    private var importWalletView: UIView?
    private var importWalletLayer = CAShapeLayer()
    private var importWalletHelpBubbleView: ImportWalletHelpBubbleView?
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
    private var currentCollectiblesContractsDisplayed = [String]()

    weak var delegate: TokensViewControllerDelegate?

    init(session: WalletSession,
         account: Wallet,
         dataStore: TokensDataStore
    ) {
		self.session = session
        self.account = account
        self.dataStore = dataStore
        self.viewModel = TokensViewModel(config: session.config, tokens: [], tickers: .none)
        tableView = UITableView(frame: .zero, style: .plain)
        super.init(nibName: nil, bundle: nil)
        dataStore.delegate = self
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addToken))

        view.backgroundColor = Colors.appBackground

        filterView.delegate = self
        filterView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterView)

        tableView.register(TokenViewCell.self, forCellReuseIdentifier: TokenViewCell.identifier)
        tableView.register(EthTokenViewCell.self, forCellReuseIdentifier: EthTokenViewCell.identifier)
        tableView.register(NonFungibleTokenViewCell.self, forCellReuseIdentifier: NonFungibleTokenViewCell.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.estimatedRowHeight = 0
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = Colors.appBackground
        tableViewRefreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        tableView.addSubview(tableViewRefreshControl)
        view.addSubview(tableView)

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
            filterView.bottomAnchor.constraint(equalTo: tableView.topAnchor, constant: -7),

            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            tableView.leadingAnchor.constraint(equalTo: collectiblesCollectionView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: collectiblesCollectionView.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: collectiblesCollectionView.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: collectiblesCollectionView.bottomAnchor),
        ])
        errorView = ErrorView(onRetry: { [weak self] in
            self?.startLoading()
            self?.dataStore.fetch()
        })
        loadingView = LoadingView()
        emptyView = EmptyView(
            title: R.string.localizable.emptyViewNoTokensLabelTitle(),
            onRetry: { [weak self] in
                self?.startLoading()
                self?.dataStore.fetch()
        })
        refreshView(viewModel: viewModel)
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

    func fetch() {
        startLoading()
        dataStore.fetch()
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
            }
            hideImportWalletImage()
        } else {
            showImportWalletImage()
        }
    }

    private func hideImportWalletImage() {
        importWalletView?.isHidden = true
		importWalletHelpBubbleView?.isHidden = true
    }

    private func showImportWalletImage() {
        if let importWalletView = importWalletView {
            importWalletView.isHidden = false
            importWalletHelpBubbleView?.isHidden = false
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
        importWalletHelpBubbleView = ImportWalletHelpBubbleView()
		let sideMargin = CGFloat(7)
        if let importWalletView = importWalletView, let importWalletHelpBubbleView = importWalletHelpBubbleView {
            view.addSubview(importWalletHelpBubbleView)

            NSLayoutConstraint.activate([
                importWalletHelpBubbleView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
                importWalletHelpBubbleView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sideMargin),
                importWalletHelpBubbleView.topAnchor.constraint(equalTo: importWalletView.bottomAnchor, constant: 7),
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
    private func contractsForCollectiblesFromViewModel() -> [String] {
        var contractsForCollectibles = [String]()
        for i in (0..<viewModel.numberOfItems(for: 0)) {
            let token = viewModel.item(for: i, section: 0)
            contractsForCollectibles.append(token.contract.lowercased())
        }
        return contractsForCollectibles
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

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCellEditingStyle.delete {
            delegate?.didDelete(token: viewModel.item(for: indexPath.row, section: indexPath.section), in: self)
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let token = viewModel.item(for: indexPath.row, section: indexPath.section)

        switch token.type {
        case .ether:
            let cellViewModel = EthTokenViewCellViewModel(
                    token: token,
                    ticker: viewModel.ticker(for: token),
                    currencyAmount: session.balanceCoordinator.viewModel.currencyAmount,
                    currencyAmountWithoutSymbol: session.balanceCoordinator.viewModel.currencyAmountWithoutSymbol
            )
            return cellViewModel.cellHeight
        case .erc20:
            let cellViewModel = TokenViewCellViewModel(token: token)
            return cellViewModel.cellHeight
        case .erc721:
            let cellViewModel = NonFungibleTokenViewCellViewModel(token: token)
            return cellViewModel.cellHeight
        case .erc875:
            let cellViewModel = NonFungibleTokenViewCellViewModel(token: token)
            return cellViewModel.cellHeight
        }
    }
}

extension TokensViewController: TokensDataStoreDelegate {
    func didUpdate(result: Result<TokensViewModel, TokenError>) {
        switch result {
        case .success(let viewModel):
            self.viewModel = viewModel
            endLoading()
        case .failure(let error):
            endLoading(error: error)
        }
        reload()

        if tableViewRefreshControl.isRefreshing {
            tableViewRefreshControl.endRefreshing()
        }
        if collectiblesCollectionViewRefreshControl.isRefreshing {
            collectiblesCollectionViewRefreshControl.endRefreshing()
        }
    }
}

extension TokensViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let token = viewModel.item(for: indexPath.row, section: indexPath.section)
        switch token.type {
        case .ether:
            let cell = tableView.dequeueReusableCell(withIdentifier: EthTokenViewCell.identifier, for: indexPath) as! EthTokenViewCell
            cell.configure(
                    viewModel: .init(
                            token: token,
                            ticker: viewModel.ticker(for: token),
                            currencyAmount: session.balanceCoordinator.viewModel.currencyAmount,
                            currencyAmountWithoutSymbol: session.balanceCoordinator.viewModel.currencyAmountWithoutSymbol
                    )
            )
            return cell
        case .erc20:
            let cell = tableView.dequeueReusableCell(withIdentifier: TokenViewCell.identifier, for: indexPath) as! TokenViewCell
            cell.configure(viewModel: .init(token: token))
            return cell
        case .erc721:
            let cell = tableView.dequeueReusableCell(withIdentifier: NonFungibleTokenViewCell.identifier, for: indexPath) as! NonFungibleTokenViewCell
            cell.configure(viewModel: .init(token: token))
            return cell
        case .erc875:
            let cell = tableView.dequeueReusableCell(withIdentifier: NonFungibleTokenViewCell.identifier, for: indexPath) as! NonFungibleTokenViewCell
            cell.configure(viewModel: .init(token: token))
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
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: OpenSeaNonFungibleTokenViewCell.identifier, for: indexPath) as! OpenSeaNonFungibleTokenViewCell
        cell.configure(viewModel: .init(token: token))
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
