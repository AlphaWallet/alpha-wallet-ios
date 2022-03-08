//
//  SelectTokenCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.07.2020.
//

import UIKit
import StatefulViewController
import Combine

protocol SelectTokenViewControllerDelegate: AnyObject {
    func controller(_ controller: SelectTokenViewController, didSelectToken token: TokenObject)
    func controller(_ controller: SelectTokenViewController, didCancelSelected sender: UIBarButtonItem)
}

class SelectTokenViewController: UIViewController {
    private lazy var viewModel = SelectTokenViewModel(
        tokensFilter: tokensFilter,
        tokens: [],
        filter: filter
    )
    private var cancellable = Set<AnyCancellable>()
    private let tokenCollection: TokenCollection
    private let assetDefinitionStore: AssetDefinitionStore
    private let sessions: ServerDictionary<WalletSession>
    private let tokensFilter: TokensFilter
    private var selectedToken: TokenObject?
    private let filter: WalletFilter
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
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

    weak var delegate: SelectTokenViewControllerDelegate?

    override func loadView() {
        view = tableView
    }

    init(sessions: ServerDictionary<WalletSession>, tokenCollection: TokenCollection, assetDefinitionStore: AssetDefinitionStore, tokensFilter: TokensFilter, filter: WalletFilter) {
        self.filter = filter
        self.sessions = sessions
        self.tokenCollection = tokenCollection
        self.assetDefinitionStore = assetDefinitionStore
        self.tokensFilter = tokensFilter

        super.init(nibName: nil, bundle: nil)
        handleTokenCollectionUpdates()

        errorView = ErrorView(onRetry: { [weak self] in
            self?.startLoading()
            self?.tokenCollection.fetch()
        })

        loadingView = LoadingView()
        emptyView = EmptyView.tokensEmptyView(completion: { [weak self] in
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

    private func configure(viewModel: SelectTokenViewModel) {
        title = viewModel.title
        view.backgroundColor = viewModel.backgroundColor
        tableView.backgroundColor = viewModel.backgroundColor
    }

    private func handleTokenCollectionUpdates() {
        tokenCollection.tokensViewModel.sink { [weak self] viewModel in
            guard let strongSelf = self else { return }
            strongSelf.viewModel = .init(tokensViewModel: viewModel, tokensFilter: strongSelf.tokensFilter, filter: strongSelf.filter)
            strongSelf.endLoading()
        }.store(in: &cancellable)
    }

    @objc private func dismiss(_ sender: UIBarButtonItem) {
        delegate?.controller(self, didCancelSelected: sender)
    }
}

extension SelectTokenViewController: StatefulViewController {
    //Always return true, otherwise users will be stuck in the assets sub-tab when they have no assets
    func hasContent() -> Bool {
        return true
    }
}

extension SelectTokenViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let token = viewModel.item(for: indexPath.row)
        selectedToken = token

        delegate?.controller(self, didSelectToken: token)
    }
}

extension SelectTokenViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let token = viewModel.item(for: indexPath.row)
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
            cell.accessoryType = viewModel.accessoryType(selectedToken, indexPath: indexPath)

            return cell
        case .erc20:
            let cell: FungibleTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: .init(token: token,
                assetDefinitionStore: assetDefinitionStore,
                ticker: session.balanceCoordinator.coinTicker(token.addressAndRPCServer)
            ))
            cell.accessoryType = viewModel.accessoryType(selectedToken, indexPath: indexPath)

            return cell
        case .erc721, .erc721ForTickets, .erc875, .erc1155:
            let cell: NonFungibleTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: .init(token: token, server: server, assetDefinitionStore: assetDefinitionStore))
            cell.accessoryType = viewModel.accessoryType(selectedToken, indexPath: indexPath)

            return cell
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfItems()
    }

    //Hide the header
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        nil
    }

    //Hide the footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
}
