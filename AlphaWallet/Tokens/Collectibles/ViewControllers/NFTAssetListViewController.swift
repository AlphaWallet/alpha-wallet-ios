//
//  NFTAssetListViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit
import StatefulViewController
import AlphaWalletFoundation

protocol NFTAssetListViewControllerDelegate: class {
    func didSelectTokenCard(in viewController: NFTAssetListViewController, tokenId: TokenId)
}

class NFTAssetListViewController: UIViewController {
    var tokenHolder: TokenHolder {
        return viewModel.tokenHolder
    }
    private var viewModel: NFTAssetListViewModel
    private let searchController: UISearchController
    private var isSearchBarConfigured = false
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.register(ContainerTableViewCell.self)
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

    weak var delegate: NFTAssetListViewControllerDelegate?

    private let tokenCardViewFactory: TokenCardViewFactory

    init(viewModel: NFTAssetListViewModel, tokenCardViewFactory: TokenCardViewFactory) {
        self.tokenCardViewFactory = tokenCardViewFactory
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

    private func configure(viewModel: NFTAssetListViewModel) {
        title = viewModel.navigationTitle
        view.backgroundColor = viewModel.backgroundColor
        tableView.backgroundColor = viewModel.backgroundColor
    }
}

extension NFTAssetListViewController: StatefulViewController {
    func hasContent() -> Bool {
        return viewModel.numberOfSections != .zero
    }
}

extension NFTAssetListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selection = viewModel.tokenHolderSelection(indexPath: indexPath)

        delegate?.didSelectTokenCard(in: self, tokenId: selection.tokenId)
    }
}

extension NFTAssetListViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let selection = viewModel.tokenHolderSelection(indexPath: indexPath)
        let cell: ContainerTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        cell.containerEdgeInsets = .zero
        cell.selectionStyle = .none
        cell.backgroundColor = viewModel.backgroundColor
        cell.contentView.backgroundColor = viewModel.backgroundColor
        cell.accessoryType = .disclosureIndicator

        let subview = tokenCardViewFactory.create(for: selection.tokenHolder, layout: .list)
        subview.configure(tokenHolder: tokenHolder, tokenId: tokenHolder.tokenId)
        cell.configure(subview: subview)

        return cell
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
