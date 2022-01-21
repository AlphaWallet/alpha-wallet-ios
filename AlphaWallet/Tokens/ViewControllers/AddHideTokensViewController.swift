// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import StatefulViewController
import PromiseKit

protocol AddHideTokensViewControllerDelegate: AnyObject {
    func didPressAddToken(in viewController: UIViewController, with addressString: String)
    func didMark(token: TokenObject, in viewController: UIViewController, isHidden: Bool)
    func didChangeOrder(tokens: [TokenObject], in viewController: UIViewController)
    func didClose(viewController: AddHideTokensViewController)
}

class AddHideTokensViewController: UIViewController {
    private let assetDefinitionStore: AssetDefinitionStore
    private var viewModel: AddHideTokensViewModel
    private let searchController: UISearchController
    private var isSearchBarConfigured = false
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.register(WalletTokenViewCell.self)
        tableView.register(PopularTokenViewCell.self)
        tableView.registerHeaderFooterView(TokensViewController.GeneralTableViewSectionHeader<DropDownView<SortTokensParam>>.self)
        //NOTE: Facing strange behavoir, while using isEditing for table view it brakes constraints while `isEditing = false` its not.
        tableView.isEditing = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .singleLine
        tableView.estimatedRowHeight = DataEntry.Metric.TableView.estimatedRowHeight
        tableView.translatesAutoresizingMaskIntoConstraints = false

        return tableView
    }()
    private let refreshControl = UIRefreshControl()

    private lazy var tokenFilterView: DropDownView<SortTokensParam> = {
        let view = DropDownView(viewModel: .init(selectionItems: SortTokensParam.allCases, selected: viewModel.sortTokensParam))
        view.delegate = self
        
        return view
    }()
    private var bottomConstraint: NSLayoutConstraint!
    private lazy var keyboardChecker = KeyboardChecker(self, resetHeightDefaultValue: 0, ignoreBottomSafeArea: true)
    weak var delegate: AddHideTokensViewControllerDelegate?

    init(viewModel: AddHideTokensViewModel, assetDefinitionStore: AssetDefinitionStore) {
        self.assetDefinitionStore = assetDefinitionStore
        self.viewModel = viewModel
        searchController = UISearchController(searchResultsController: nil)
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
        searchController.delegate = self

        emptyView = EmptyView.filterTokensEmptyView(completion: { [weak self] in
            guard let strongSelf = self, let delegate = strongSelf.delegate else { return }
            let addressString = strongSelf.searchController.searchBar.text ?? ""
            delegate.didPressAddToken(in: strongSelf, with: addressString)
        }) 

        view.addSubview(tableView)

        bottomConstraint = tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        keyboardChecker.constraints = [bottomConstraint]

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomConstraint
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure(viewModel: viewModel)
        setupFilteringWithKeyword()

        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem.addButton(self, selector: #selector(addToken))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        keyboardChecker.viewWillAppear()
        reload()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        keyboardChecker.viewWillDisappear()

        if isMovingFromParent || isBeingDismissed {
            delegate?.didClose(viewController: self)
            return
        }
    }

    override func viewDidLayoutSubviews() {
        configureSearchBarOnce()
    }

    @objc private func addToken() {
        delegate?.didPressAddToken(in: self, with: "")
    }

    private func configure(viewModel: AddHideTokensViewModel) {
        title = viewModel.title
        tableView.backgroundColor = viewModel.backgroundColor
        view.backgroundColor = viewModel.backgroundColor

        tokenFilterView.configure(viewModel: .init(selectionItems: SortTokensParam.allCases, selected: viewModel.sortTokensParam))
    }

    private func reload() {
        startLoading(animated: false)
        tableView.reloadData()
        endLoading(animated: false)
    }

    func add(token: TokenObject) {
        viewModel.add(token: token)
        reload()
    }

    func set(popularTokens: [PopularToken]) {
        viewModel.set(allPopularTokens: popularTokens)

        DispatchQueue.main.async {
            self.reload()
        }
    }
}

extension AddHideTokensViewController: StatefulViewController {
    func hasContent() -> Bool {
        return !viewModel.sections.isEmpty
    }
}

extension AddHideTokensViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        viewModel.numberOfSections
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.numberOfItems(section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let token = viewModel.item(atIndexPath: indexPath) else { return UITableViewCell() }
        let isVisible = viewModel.displayedToken(indexPath: indexPath)

        switch token {
        case .walletToken(let tokenObject):
            let cell: WalletTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: .init(token: tokenObject, assetDefinitionStore: assetDefinitionStore, isVisible: isVisible))

            return cell
        case .popularToken(let value):
            let cell: PopularTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: .init(token: value, isVisible: isVisible))

            return cell
        }
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        if let tokens = viewModel.moveItem(from: sourceIndexPath, to: destinationIndexPath) {
            delegate?.didChangeOrder(tokens: tokens, in: self)
        }
        reload()
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        viewModel.canMoveItem(indexPath: indexPath)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let result: AddHideTokensViewModel.ShowHideOperationResult
        let isTokenHidden: Bool

        switch editingStyle {
        case .insert:
            result = viewModel.addDisplayed(indexPath: indexPath)
            isTokenHidden = false
        case .delete:
            result = viewModel.deleteToken(indexPath: indexPath)
            isTokenHidden = true
        case .none:
            result = .value(nil)
            isTokenHidden = false
        }

        switch result {
        case .value(let result):
            if let result = result, let delegate = delegate {
                delegate.didMark(token: result.token, in: self, isHidden: isTokenHidden)
                tableView.performBatchUpdates({
                    tableView.insertRows(at: [result.indexPathToInsert], with: .automatic)
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                }, completion: nil)
            } else {
                tableView.reloadData()
            }
        case .promise(let promise):
            self.displayLoading()
            promise.done(on: .none, flags: .barrier) { [weak self] result in
                guard let strongSelf = self else { return }

                if let result = result, let delegate = strongSelf.delegate {
                    delegate.didMark(token: result.token, in: strongSelf, isHidden: isTokenHidden)
                }
            }.catch { _ in
                self.displayError(message: R.string.localizable.walletsHideTokenErrorAddTokenFailure())
            }.finally {
                tableView.reloadData()

                self.hideLoading()
            }
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let title = R.string.localizable.walletsHideTokenTitle()
        let hideAction = UIContextualAction(style: .destructive, title: title) { [weak self] _, _, completionHandler in
            guard let strongSelf = self else { return }

            switch strongSelf.viewModel.deleteToken(indexPath: indexPath) {
            case .value(let result):
                if let result = result, let delegate = strongSelf.delegate {
                    delegate.didMark(token: result.token, in: strongSelf, isHidden: true)

                    tableView.performBatchUpdates({
                        tableView.deleteRows(at: [indexPath], with: .automatic)
                        tableView.insertRows(at: [result.indexPathToInsert], with: .automatic)
                    }, completion: nil)

                    completionHandler(true)
                } else {
                    tableView.reloadData()

                    completionHandler(false)
                }
            case .promise:
                break
            }
        }

        hideAction.backgroundColor = R.color.danger()
        hideAction.image = R.image.hideToken()

        let configuration = UISwipeActionsConfiguration(actions: [hideAction])
        configuration.performsFirstActionWithFullSwipe = true

        return configuration
    }
}

extension AddHideTokensViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        viewModel.editingStyle(indexPath: indexPath)
    }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        false
    }

    func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        if sourceIndexPath.section != proposedDestinationIndexPath.section {
            var row = 0
            if sourceIndexPath.section < proposedDestinationIndexPath.section {
                row = self.tableView(tableView, numberOfRowsInSection: sourceIndexPath.section) - 1
            }
            return IndexPath(row: row, section: sourceIndexPath.section)
        }
        return proposedDestinationIndexPath
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch viewModel.sections[section] {
        case .sortingFilters:
            let header = TokensViewController.ContainerView(subview: tokenFilterView)
            header.useSeparatorLine = true
            return header
        case .availableNewTokens, .popularTokens, .hiddenTokens, .displayedTokens:
            let viewModel: AddHideTokenSectionHeaderViewModel = .init(titleText: self.viewModel.titleForSection(section))
            return AddHideTokensViewController.functional.headerView(for: section, viewModel: viewModel)
        }
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    //Hide the footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
}

extension AddHideTokensViewController: DropDownViewDelegate {
    func filterDropDownViewDidChange(selection: ControlSelection) {
        guard let filterParam = tokenFilterView.value(from: selection) else { return }

        viewModel.sortTokensParam = filterParam
        reload()
    }
}

extension AddHideTokensViewController: UISearchControllerDelegate {
    func willPresentSearchController(_ searchController: UISearchController) {
        viewModel.isSearchActive = true
    }

    func willDismissSearchController(_ searchController: UISearchController) {
        viewModel.isSearchActive = false
    }
}

extension AddHideTokensViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.viewModel.searchText = searchController.searchBar.text ?? ""
            strongSelf.reload()
        }
    }
}

///Support searching/filtering tokens with keywords. This extension is set up so it's easier to copy and paste this functionality elsewhere
extension AddHideTokensViewController {
    private func makeSwitchToAnotherTabWorkWhileFiltering() {
        definesPresentationContext = true
    }

    private func wireUpSearchController() {
        searchController.searchResultsUpdater = self
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
    }

    private func fixTableViewBackgroundColor() {
        let v = UIView()
        v.backgroundColor = viewModel.backgroundColor
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

    private func doNotDimTableViewToReuseTableForFilteringResult() {
        searchController.obscuresBackgroundDuringPresentation = false
    }

    //Makes a difference where this is called from. Can't be too early
    private func configureSearchBarOnce() {
        guard !isSearchBarConfigured else { return }
        isSearchBarConfigured = true
        UISearchBar.configure(searchBar: searchController.searchBar)
    }
}
