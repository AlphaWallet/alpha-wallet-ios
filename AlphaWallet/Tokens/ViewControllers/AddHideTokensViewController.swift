// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import StatefulViewController

protocol AddHideTokensViewControllerDelegate: class {
    func didPressAddToken( in viewController: UIViewController)
    func didMark(token: TokenObject, in viewController: UIViewController, isHidden: Bool)
    func didChangeOrder(tokens: [TokenObject], in viewController: UIViewController)
    func didClose(viewController: AddHideTokensViewController)
}

class AddHideTokensViewController: UIViewController {
    private let assetDefinitionStore: AssetDefinitionStore
    private let sessions: ServerDictionary<WalletSession>
    private var viewModel: AddHideTokensViewModel
    private let searchController: UISearchController
    private var isSearchBarConfigured = false
    private lazy var tableView: UITableView = UITableView(frame: .zero, style: .grouped)
    private let refreshControl = UIRefreshControl()
    private var prefersLargeTitles: Bool?

    weak var delegate: AddHideTokensViewControllerDelegate?

    init(viewModel: AddHideTokensViewModel, sessions: ServerDictionary<WalletSession>, assetDefinitionStore: AssetDefinitionStore) { 
        self.assetDefinitionStore = assetDefinitionStore
        self.sessions = sessions
        self.viewModel = viewModel
        searchController = UISearchController(searchResultsController: nil)

        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        view = tableView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        refreshView(viewModel: viewModel)
        setup(tableView: tableView)
        setupFilteringWithKeyword()

        navigationItem.rightBarButtonItem = UIBarButtonItem(image: R.image.plus(), style: .plain, target: self, action: #selector(addToken))
        navigationItem.rightBarButtonItem?.width = 30
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        prefersLargeTitles = navigationController?.navigationBar.prefersLargeTitles
        navigationController?.navigationBar.prefersLargeTitles = false

        reload()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if isMovingFromParent || isBeingDismissed {
            delegate?.didClose(viewController: self)
            return
        }

        if let prefersLargeTitles = prefersLargeTitles {
            navigationController?.navigationBar.prefersLargeTitles = prefersLargeTitles
        }
        prefersLargeTitles = nil
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        configureSearchBarOnce()
    }

    @objc private func addToken() {
        delegate?.didPressAddToken(in: self)
    }

    private func refreshView(viewModel: AddHideTokensViewModel) {
        title = viewModel.title
        tableView.backgroundColor = viewModel.backgroundColor
    }

    private func setup(tableView: UITableView) {
        tableView.register(FungibleTokenViewCell.self)
        tableView.register(NonFungibleTokenViewCell.self)
        tableView.register(EthTokenViewCell.self) 
        tableView.registerHeaderFooterView(AddHideTokenSectionHeaderView.self)
        tableView.isEditing = true
        tableView.estimatedRowHeight = 100
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .singleLine
        tableView.separatorInset = .zero
        tableView.contentInset = .zero
        tableView.contentOffset = .zero
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.size.width, height: 0.01))
    }

    func reload() {
        tableView.reloadData()
    }
}

extension AddHideTokensViewController: StatefulViewController {
    //Always return true, otherwise users will be stuck in the assets sub-tab when they have no assets
    func hasContent() -> Bool {
        true
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

        let session = sessions[token.server]
        switch token.type {
        case .nativeCryptocurrency:
            let cell: EthTokenViewCell = tableView.dequeueReusableCell(for: indexPath)

            cell.configure(
                    viewModel: .init(
                            token: token,
                            ticker: viewModel.ticker(for: token),
                            currencyAmount: session.balanceCoordinator.viewModel.currencyAmount,
                            currencyAmountWithoutSymbol: session.balanceCoordinator.viewModel.currencyAmountWithoutSymbol,
                            server: token.server,
                            assetDefinitionStore: assetDefinitionStore,
                            isVisible: isVisible
                    )
            )
            return cell
        case .erc20:
            let cell: FungibleTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel:
                .init(token: token,
                      server: token.server,
                      assetDefinitionStore: assetDefinitionStore,
                      isVisible: isVisible
                )
            )
            return cell
        case .erc721, .erc721ForTickets:
            let cell: NonFungibleTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel:
                .init(token: token,
                      server: token.server,
                      assetDefinitionStore: assetDefinitionStore,
                      isVisible: isVisible
                )
            )
            return cell
        case .erc875:
            let cell: NonFungibleTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel:
                .init(token: token,
                      server: token.server,
                      assetDefinitionStore: assetDefinitionStore,
                      isVisible: isVisible
                )
            )

            return cell
        }
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        if let tokens = viewModel.moveItem(from: sourceIndexPath, to: destinationIndexPath) {
            delegate?.didChangeOrder(tokens: tokens, in: self)
        }
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        viewModel.canMoveItem(indexPath: indexPath)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let result: (token: TokenObject, indexPathToInsert: IndexPath)?
        let isTokenHidden: Bool
        switch editingStyle {
        case .insert:
            result = viewModel.addDisplayed(indexPath: indexPath)
            isTokenHidden = false
        case .delete:
            result = viewModel.deleteToken(indexPath: indexPath)
            isTokenHidden = true
        case .none:
            result = nil
            isTokenHidden = false
        }

        if let result = result {
            delegate?.didMark(token: result.token, in: self, isHidden: isTokenHidden)
            tableView.performBatchUpdates({
                tableView.deleteRows(at: [indexPath], with: .automatic)
                tableView.insertRows(at: [result.indexPathToInsert], with: .automatic)
            }, completion: nil)
        } else {
            tableView.reloadData()
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let title = R.string.localizable.walletsHideTokenTitle()
        let hideAction = UIContextualAction(style: .destructive, title: title) { [weak self] _, _, completionHandler in
            guard let strongSelf = self else { return }
            if let result = strongSelf.viewModel.deleteToken(indexPath: indexPath) {
                strongSelf.delegate?.didMark(token: result.token, in: strongSelf, isHidden: true)
                tableView.performBatchUpdates({
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                    tableView.insertRows(at: [result.indexPathToInsert], with: .automatic)
                }, completion: nil)
                completionHandler(true)
            } else {
                tableView.reloadData()
                completionHandler(false)
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
        let view: AddHideTokenSectionHeaderView = tableView.dequeueReusableHeaderFooterView()
        view.configure(viewModel: .init(text: viewModel.titleForSection(section)))
        
        return view
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        65
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

    private func doNotDimTableViewToReuseTableForFilteringResult() {
        searchController.dimsBackgroundDuringPresentation = false
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

    //Makes a difference where this is called from. Can't be too early
    private func configureSearchBarOnce() {
        guard !isSearchBarConfigured else { return }
        isSearchBarConfigured = true

        if let placeholderLabel = searchController.searchBar.firstSubview(ofType: UILabel.self) {
            placeholderLabel.textColor = Colors.lightGray
        }
        if let textField = searchController.searchBar.firstSubview(ofType: UITextField.self) {
            textField.textColor = Colors.appText
            if let imageView = textField.leftView as? UIImageView {
                imageView.image = imageView.image?.withRenderingMode(.alwaysTemplate)
                imageView.tintColor = Colors.appText
            }
        }
        //Hack to hide the horizontal separator below the search bar
        searchController.searchBar.superview?.firstSubview(ofType: UIImageView.self)?.isHidden = true
    }
}
