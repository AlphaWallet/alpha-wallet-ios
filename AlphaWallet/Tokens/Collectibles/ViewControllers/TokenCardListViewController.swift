//
//  TokenCardListViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit

protocol TokenCardListViewControllerDelegate: class {
    func selectTokenCardsSelected(in viewController: TokenCardListViewController)
    func didSelectTokenCard(in viewController: TokenCardListViewController, tokenId: TokenId)
}

class TokenCardListViewControllerViewModel {
    let tokenHolder: TokenHolder
    private var filteredTokenHolders: [TokenHolderWithItsTokenIds] = []

    var headerBackgroundColor: UIColor = Colors.appWhite

    var navigationTitle: String {
        return tokenHolder.name
    }

    var backgroundColor: UIColor = GroupedTable.Color.background

    var isSearchActive: Bool = false
    
    var numberOfSections: Int {
        filteredTokenHolders.count
    }

    func numberOfTokens(section: Int) -> Int {
        return filteredTokenHolders[section].tokensIds.count
    }

    func titleForTokenHolder(section: Int) -> String {
        return filteredTokenHolders[section].tokenHolder.name
    }

    func tokenHolderSelection(indexPath: IndexPath) -> TokenHolderSelection {
        let pair = filteredTokenHolders[indexPath.section]

        return (pair.tokensIds[indexPath.row], pair.tokenHolder)
    }

    func selectableTokenHolder(at section: Int) -> TokenHolder {
        return filteredTokenHolders[section].tokenHolder
    }

    init(tokenHolder: TokenHolder) {
        self.tokenHolder = tokenHolder

        filteredTokenHolders = [
            .init(tokenHolder: tokenHolder, tokensIds: tokenHolder.tokenIds)
        ]
    }
}

class TokenCardListViewController: UIViewController {
    var tokenHolder: TokenHolder {
        return viewModel.tokenHolder
    }
    private var viewModel: TokenCardListViewControllerViewModel
    private let searchController: UISearchController
    private var isSearchBarConfigured = false
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.register(TokenCardContainerTableViewCell.self)
        tableView.dataSource = self
        tableView.estimatedRowHeight = 100
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.separatorInset = .zero
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.allowsMultipleSelection = true
        tableView.allowsMultipleSelectionDuringEditing = true

        return tableView
    }()

    private let roundedBackground = RoundedBackground()

    weak var delegate: TokenCardListViewControllerDelegate?

    private lazy var factory: TokenCardTableViewCellFactory = {
        TokenCardTableViewCellFactory()
    }()

    private var cachedCellsCardRowViews: [IndexPath: UIView & TokenCardRowViewProtocol] = [:]
    private let assetDefinitionStore: AssetDefinitionStore
    private let analyticsCoordinator: AnalyticsCoordinator
    private let server: RPCServer
    private let tokenObject: TokenObject

    init(viewModel: TokenCardListViewControllerViewModel, tokenObject: TokenObject, assetDefinitionStore: AssetDefinitionStore, analyticsCoordinator: AnalyticsCoordinator, server: RPCServer) {
        self.tokenObject = tokenObject
        self.assetDefinitionStore = assetDefinitionStore
        self.analyticsCoordinator = analyticsCoordinator
        self.server = server
        self.viewModel = viewModel
        searchController = UISearchController(searchResultsController: nil)
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
        roundedBackground.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(roundedBackground)

        roundedBackground.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: roundedBackground.bottomAnchor)
        ] + roundedBackground.createConstraintsWithContainer(view: view))

        configure(viewModel: viewModel)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func reload() {
        startLoading(animated: false)
        tableView.reloadData()
        endLoading(animated: false)
    }

    private func configure(viewModel: TokenCardListViewControllerViewModel) {
        title = viewModel.navigationTitle
        view.backgroundColor = viewModel.backgroundColor
        tableView.backgroundColor = viewModel.backgroundColor
    }
}

import StatefulViewController

extension TokenCardListViewController: StatefulViewController {
    func hasContent() -> Bool {
        return viewModel.numberOfSections != .zero
    }
}

extension TokenCardListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selection = viewModel.tokenHolderSelection(indexPath: indexPath)

        delegate?.didSelectTokenCard(in: self, tokenId: selection.tokenId)
    }
}

extension TokenCardListViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let selection = viewModel.tokenHolderSelection(indexPath: indexPath)
        let cell: TokenCardContainerTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        cell.containerEdgeInsets = .zero

        let subview: UIView & TokenCardRowViewProtocol
        if let value = cachedCellsCardRowViews[indexPath] {
            subview = value
        } else {
            subview = factory.create(for: selection.tokenHolder)

            cachedCellsCardRowViews[indexPath] = subview
        }

        cell.configure(subview: subview)
        configure(container: cell, tokenId: selection.tokenId, tokenHolder: selection.tokenHolder)

        return cell
    }

    private func configure(container: TokenCardContainerTableViewCell, tokenId: TokenId, tokenHolder: TokenHolder) {
        container.configure(viewModel: .init(tokenHolder: tokenHolder, cellWidth: tableView.frame.size.width, tokenView: .viewIconified), tokenId: tokenId, assetDefinitionStore: assetDefinitionStore)
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfTokens(section: section)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }

    //Hide the footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
}
