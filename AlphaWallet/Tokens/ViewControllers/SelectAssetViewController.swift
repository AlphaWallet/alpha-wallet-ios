//
//  SelectAssetCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.07.2020.
//

import UIKit
import StatefulViewController

protocol SelectAssetViewControllerDelegate: class {
    func controller(_ controller: SelectAssetViewController, didSelectToken token: TokenObject)
    func controller(_ controller: SelectAssetViewController, didCancelSelected sender: UIBarButtonItem)
}

class SelectAssetViewController: UIViewController {
    private lazy var viewModel = SelectAssetViewModel(
        filterTokensCoordinator: filterTokensCoordinator,
        tokens: [],
        tickers: [:],
        filter: filter
    )
    private let tokenCollection: TokenCollection
    private let assetDefinitionStore: AssetDefinitionStore
    private let sessions: ServerDictionary<WalletSession>
    private let filterTokensCoordinator: FilterTokensCoordinator
    private var selectedToken: TokenObject?
    private let filter: WalletFilter
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.register(FungibleTokenViewCell.self)
        tableView.register(EthTokenViewCell.self)
        tableView.register(NonFungibleTokenViewCell.self)
        tableView.dataSource = self
        tableView.estimatedRowHeight = 100
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.separatorInset = .zero
        tableView.translatesAutoresizingMaskIntoConstraints = false

        return tableView
    }()

    weak var delegate: SelectAssetViewControllerDelegate?

    override func loadView() {
        view = tableView
    }

    init(sessions: ServerDictionary<WalletSession>, tokenCollection: TokenCollection, assetDefinitionStore: AssetDefinitionStore, filterTokensCoordinator: FilterTokensCoordinator, filter: WalletFilter) {
        self.filter = filter
        self.sessions = sessions
        self.tokenCollection = tokenCollection
        self.assetDefinitionStore = assetDefinitionStore
        self.filterTokensCoordinator = filterTokensCoordinator

        super.init(nibName: nil, bundle: nil)
        handleTokenCollectionUpdates()

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

        configure(viewModel: viewModel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.applyTintAdjustment()
        navigationController?.navigationBar.prefersLargeTitles = false
        hidesBottomBarWhenPushed = true
        navigationItem.rightBarButtonItem = UIBarButtonItem.closeBarButton(self, selector: #selector(dismiss))

        fetchTokens()
    }

    private func fetchTokens() {
        startLoading()
        tokenCollection.fetch()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func configure(viewModel: SelectAssetViewModel) {
        title = viewModel.title
        view.backgroundColor = viewModel.backgroundColor
        tableView.backgroundColor = viewModel.backgroundColor
    }

    private func handleTokenCollectionUpdates() {
        tokenCollection.subscribe { [weak self] result in
            guard let strongSelf = self else { return }

            switch result {
            case .success(let viewModel):
                strongSelf.viewModel = .init(tokensViewModel: viewModel, filterTokensCoordinator: strongSelf.filterTokensCoordinator, filter: strongSelf.filter)
                strongSelf.endLoading()
            case .failure(let error):
                strongSelf.endLoading(error: error)
            }

            strongSelf.tableView.reloadData()
        }
    }

    @objc private func dismiss(_ sender: UIBarButtonItem) {
        delegate?.controller(self, didCancelSelected: sender)
    }
}

extension SelectAssetViewController: StatefulViewController {
    //Always return true, otherwise users will be stuck in the assets sub-tab when they have no assets
    func hasContent() -> Bool {
        return true
    }
}

extension SelectAssetViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let token = viewModel.item(for: indexPath.row)
        selectedToken = token

        delegate?.controller(self, didSelectToken: token)
    }
}

extension SelectAssetViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let token = viewModel.item(for: indexPath.row)
        let server = token.server
        let session = sessions[server]

        switch token.type {
        case .nativeCryptocurrency:
            let cell: EthTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: .init(
                token: token,
                ticker: viewModel.ticker(for: token),
                currencyAmount: session.balanceCoordinator.viewModel.currencyAmount,
                currencyAmountWithoutSymbol: session.balanceCoordinator.viewModel.currencyAmountWithoutSymbol,
                server: server,
                assetDefinitionStore: assetDefinitionStore
            ))
            cell.accessoryType = viewModel.accessoryType(selectedToken, indexPath: indexPath)

            return cell
        case .erc20:
            let cell: FungibleTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: .init(token: token, server: server, assetDefinitionStore: assetDefinitionStore))
            cell.accessoryType = viewModel.accessoryType(selectedToken, indexPath: indexPath)

            return cell
        case .erc721, .erc721ForTickets, .erc875:
            let cell: NonFungibleTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: .init(token: token, server: server, assetDefinitionStore: assetDefinitionStore))
            cell.accessoryType = viewModel.accessoryType(selectedToken, indexPath: indexPath)

            return cell
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfItems()
    }
}
