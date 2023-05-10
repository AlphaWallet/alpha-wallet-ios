//
//  SaveCustomRpcBrowseViewController.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 21/12/21.
//

import UIKit
import AlphaWalletFoundation
import AlphaWalletLogger

protocol SaveCustomRpcBrowseViewControllerDataDelegate: AnyObject {
    func didFinish(in viewController: SaveCustomRpcBrowseViewController, customRpcArray: [CustomRPC])
}

protocol SaveCustomRpcBrowseViewControllerSearchDelegate: AnyObject {
    func showSearchController()
}

protocol SaveCustomRpcBrowseViewControllerConfigurationDelegate: AnyObject {
    func enableAddFunction(_ status: Bool)
}

class SaveCustomRpcBrowseViewController: UIViewController {

    // MARK: - Properties
    // MARK: Private

    private let dataController: SaveCustomRpcBrowseDataController
    private var tableViewTopToTopLayout: NSLayoutConstraint?
    private var tableViewTopToSearchBarLayout: NSLayoutConstraint?
    private lazy var footerView = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0)
    
    // MARK: Public

    weak var dataDelegate: SaveCustomRpcBrowseViewControllerDataDelegate?
    weak var searchDelegate: SaveCustomRpcBrowseViewControllerSearchDelegate?

    var browseView: SaveCustomRpcBrowseView {
        return view as! SaveCustomRpcBrowseView
    }

    // MARK: - UI Elements

    private lazy var tableViewController: UITableViewController = {
        let tableViewController = UITableViewController(style: .grouped)
        tableViewController.tableView.dataSource = dataController
        tableViewController.tableView.translatesAutoresizingMaskIntoConstraints = false
        tableViewController.tableView.delegate = dataController
        tableViewController.tableView.separatorStyle = .singleLine
        tableViewController.tableView.backgroundColor = Configuration.Color.Semantic.tableViewBackground
        tableViewController.tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableViewController.tableView.isEditing = false
        tableViewController.tableView.register(RPCDisplayTableViewCell.self)
        return tableViewController
    }()

    private lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        return searchBar
    }()

    private lazy var emptyView: UIView = {
        let emptyView = EmptyTableView(title: R.string.localizable.searchNetworkResultEmpty(), image: R.image.empty_list()!, heightAdjustment: 100.0)
        emptyView.isHidden = true
        return emptyView
    }()

    private lazy var buttonsBar: HorizontalButtonsBar = {
        let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
        buttonsBar.translatesAutoresizingMaskIntoConstraints = false
        return buttonsBar
    }()

    // MARK: - Constructors

    init(viewModel: SaveCustomRpcBrowseDataController) {
        self.dataController = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        configureViewController()
    }

    override func loadView() {
        view = SaveCustomRpcBrowseView()
    }

    // MARK: - Configuration

    private func configureViewController() {
        configureAddNetworkButton()
        configureSearchBar()
        configureTableViewController()
        configureEmptyView()
        tableViewTopToTopLayout = tableViewController.tableView.topAnchor.constraint(equalTo: browseView.topAnchor)
        tableViewTopToSearchBarLayout = tableViewController.tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor)
        showSearchBar()
        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
    }

    private func configureTableViewController() {
        addChild(tableViewController)
        browseView.addSubview(tableViewController.tableView)
        NSLayoutConstraint.activate([
            tableViewController.tableView.leadingAnchor.constraint(equalTo: browseView.leadingAnchor),
            tableViewController.tableView.trailingAnchor.constraint(equalTo: browseView.trailingAnchor),
            tableViewController.tableView.bottomAnchor.constraint(equalTo: footerView.topAnchor)
        ])
        tableViewController.didMove(toParent: self)
    }

    private func configureEmptyView() {
        tableViewController.tableView.addSubview(emptyView)
        NSLayoutConstraint.activate([
            emptyView.centerXAnchor.constraint(equalTo: tableViewController.tableView.centerXAnchor),
            emptyView.centerYAnchor.constraint(equalTo: tableViewController.tableView.centerYAnchor),
        ])
    }

    private func configureSearchBar() {
        searchBar.delegate = self
        searchBar.placeholder = R.string.localizable.customRPCBrowseSearchPlaceholder()
        browseView.addSubview(searchBar)
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: browseView.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: browseView.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: browseView.trailingAnchor)
        ])
    }

    private func configureAddNetworkButton() {
        buttonsBar.configure()
        buttonsBar.buttons[0].setTitle(R.string.localizable.addrpcServerSaveButtonTitle(preferredLanguages: nil), for: .normal)
        addSaveButtonTarget(self, action: #selector(handleAddButtonAction(_:)))
        enableAddFunction(false)

        view.addSubview(footerView)

        NSLayoutConstraint.activate([
            footerView.anchorsConstraint(to: view)
        ])
    }

    // MARK: - Search bar

    func hideSearchBar() {
        tableViewTopToTopLayout?.isActive = true
        tableViewTopToSearchBarLayout?.isActive = false
        tableViewController.tableView.setNeedsUpdateConstraints()
    }

    func showSearchBar() {
        tableViewTopToTopLayout?.isActive = false
        tableViewTopToSearchBarLayout?.isActive = true
        tableViewController.tableView.setNeedsUpdateConstraints()
    }

    // MARK: - Search

    func resetFilter() {
        dataController.reset()
    }

    func filter(phrase: String) {
        dataController.filter(phrase: phrase)
    }

    // MARK: - Handle Empty Search Results

    func handleEmptyTableAction(_ rows: Int) {
        let newViewHiddenState = rows != 0
        guard emptyView.isHidden != newViewHiddenState else { return }
        emptyView.isHidden = newViewHiddenState
    }

    // MARK: - objc handlers

    @objc private func handleAddButtonAction(_ sender: Any) {
        dataDelegate?.didFinish(in: self, customRpcArray: selectedServers())
    }

    // MARK: - private functions

    private func addSaveButtonTarget(_ target: Any?, action: Selector) {
        let button = buttonsBar.buttons[0]
        button.removeTarget(target, action: action, for: .touchUpInside)
        button.addTarget(target, action: action, for: .touchUpInside)
    }

}

// MARK: - UISearchBarDelegate

extension SaveCustomRpcBrowseViewController: UISearchBarDelegate {

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        self.searchDelegate?.showSearchController()
    }

}

// MARK: - UISearchResultsUpdating

extension SaveCustomRpcBrowseViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        guard let searchPhrase = searchController.searchBar.text else { return }
        dataController.filter(phrase: searchPhrase)
    }

}

// MARK: - DataObserver

extension SaveCustomRpcBrowseViewController: SaveCustomRpcBrowseDataObserver {

    func dataHasChanged(rows: Int) {
        self.tableViewController.tableView.reloadData()
        self.handleEmptyTableAction(rows)
    }

    func selectedServers() -> [CustomRPC] {
        return dataController.selectedServers()
    }

}

extension SaveCustomRpcBrowseViewController: HandleAddMultipleCustomRpcViewControllerResponse {

    // We get four arrays, added, failed, duplicates, remaining
    // For added, failed, duplicates we simply remove the added customRPCs from all the sections
    // For remaining, we do nothing, maybe user pressed cancel and these haven't been added yet?

    func handleAddMultipleCustomRpcFailure(added: NSArray, failed: NSArray, duplicates: NSArray, remaining: NSArray) {
        guard let addedCustomRpc: [CustomRPC] = added as? [CustomRPC], let duplicatedCustomRpc: [CustomRPC] = duplicates as? [CustomRPC], let failedCustomRpc: [CustomRPC] = failed as? [CustomRPC] else { return }
        let toBeRemovedCustomRpcs = addedCustomRpc+duplicatedCustomRpc+failedCustomRpc
        dataController.remove(customRpcs: toBeRemovedCustomRpcs)
        tableViewController.tableView.reloadData()
        var errorMessage: String = ""
        if let failed: [CustomRPC] = failed as? [CustomRPC], !failed.isEmpty {
            errorMessage = R.string.localizable.addMultipleCustomRpcError(preferredLanguages: nil)
            reportFailures(customRpcs: failed)
        }
        if let duplicates: [CustomRPC] = duplicates as? [CustomRPC], !duplicates.isEmpty {
            errorMessage = R.string.localizable.addMultipleCustomRpcError(preferredLanguages: nil)
        }
        if !errorMessage.isEmpty {
            displayError(message: errorMessage)
        }
    }

    private func reportFailures(customRpcs: [CustomRPC]) {
        customRpcs.forEach { customRpc in
            infoLog("[Custom chains] Failed to add: \(customRpc.chainName) chainID: \(customRpc.chainID) endPoint: \(customRpc.rpcEndpoint)")
        }
    }

}

extension SaveCustomRpcBrowseViewController: SaveCustomRpcBrowseViewControllerConfigurationDelegate {

    func enableAddFunction(_ status: Bool) {
        buttonsBar.buttons[0].isEnabled = status
    }

}
