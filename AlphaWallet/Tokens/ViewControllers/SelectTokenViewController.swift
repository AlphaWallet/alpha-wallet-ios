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
    func controller(_ controller: SelectTokenViewController, didSelectToken token: Token)
}

class SelectTokenViewController: UIViewController {
    private lazy var viewModel = SelectTokenViewModel(
        tokensFilter: tokenCollection.tokensFilter,
        tokens: [],
        filter: filter
    )
    private var cancellable = Set<AnyCancellable>()
    private let tokenCollection: TokenCollection
    private let assetDefinitionStore: AssetDefinitionStore
    private var selectedToken: Token?
    private let wallet: Wallet
    private let tokenBalanceService: TokenBalanceService
    private let filter: WalletFilter
    private let eventsDataStore: NonActivityEventsDataStore
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
    private (set) lazy var headerView: ConfirmationHeaderView = {
        let view = ConfirmationHeaderView(viewModel: .init(title: viewModel.navigationTitle))
        view.isHidden = true

        return view
    }()

    init(wallet: Wallet, tokenBalanceService: TokenBalanceService, tokenCollection: TokenCollection, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: NonActivityEventsDataStore, filter: WalletFilter) {
        self.wallet = wallet
        self.tokenBalanceService = tokenBalanceService
        self.filter = filter
        self.tokenCollection = tokenCollection
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore

        super.init(nibName: nil, bundle: nil)

        let stackView = [headerView, tableView].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: view)
        ])

        errorView = ErrorView(onRetry: { [weak self] in
            self?.startLoading()
            self?.tokenCollection.fetch()
        })

        loadingView = LoadingView(insets: .init(top: Style.SearchBar.height, left: 0, bottom: 0, right: 0))
        emptyView = EmptyView.tokensEmptyView(completion: { [weak self] in
            self?.startLoading()
            self?.tokenCollection.fetch()
        }) 

        configure(viewModel: viewModel)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        handleTokenCollectionUpdates()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.applyTintAdjustment()
        navigationController?.navigationBar.prefersLargeTitles = false
        hidesBottomBarWhenPushed = true

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
        title = viewModel.navigationTitle
        view.backgroundColor = viewModel.backgroundColor
        tableView.backgroundColor = viewModel.backgroundColor
    }

    private func handleTokenCollectionUpdates() {
        tokenCollection.tokensViewModel.sink { [weak self] viewModel in
            guard let strongSelf = self else { return }
            strongSelf.viewModel = .init(tokensViewModel: viewModel, tokensFilter: strongSelf.tokenCollection.tokensFilter, filter: strongSelf.filter)
            strongSelf.endLoading()
        }.store(in: &cancellable)
    }
}

extension SelectTokenViewController: StatefulViewController {
    func hasContent() -> Bool {
        return viewModel.numberOfItems() > 0
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
        switch token.type {
        case .nativeCryptocurrency:
            let cell: EthTokenViewCell = tableView.dequeueReusableCell(for: indexPath)

            cell.configure(viewModel: .init(
                token: token,
                ticker: tokenBalanceService.coinTicker(token.addressAndRPCServer),
                currencyAmount: tokenBalanceService.ethBalanceViewModel?.currencyAmountWithoutSymbol,
                assetDefinitionStore: assetDefinitionStore
            ))
            cell.accessoryType = viewModel.accessoryType(selectedToken, indexPath: indexPath)

            return cell
        case .erc20:
            let cell: FungibleTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: .init(token: token,
                assetDefinitionStore: assetDefinitionStore,
                eventsDataStore: eventsDataStore,
                wallet: wallet,
                ticker: tokenBalanceService.coinTicker(token.addressAndRPCServer)
            ))
            cell.accessoryType = viewModel.accessoryType(selectedToken, indexPath: indexPath)

            return cell
        case .erc721, .erc721ForTickets, .erc875, .erc1155:
            let cell: NonFungibleTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: .init(token: token, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, wallet: wallet))
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
