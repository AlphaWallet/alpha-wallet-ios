// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import StatefulViewController
import Combine
import AlphaWalletFoundation

protocol AddHideTokensViewControllerDelegate: AnyObject {
    func didPressAddToken(in viewController: UIViewController, with addressString: String)
    func didClose(in viewController: AddHideTokensViewController)
}

class AddHideTokensViewController: UIViewController {
    private let viewModel: AddHideTokensViewModel
    private let searchController: UISearchController
    private var isSearchBarConfigured = false
    private lazy var tableView: UITableView = {
        let tableView = UITableView.buildGroupedTableView()
        tableView.register(WalletTokenViewCell.self)
        tableView.register(PopularTokenViewCell.self)
        tableView.registerHeaderFooterView(TokensViewController.GeneralTableViewSectionHeader<DropDownView<SortTokensParam>>.self)
        //NOTE: Facing strange behavoir, while using isEditing for table view it brakes constraints while `isEditing = false` its not.
        tableView.isEditing = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.estimatedRowHeight = DataEntry.Metric.TableView.estimatedRowHeight

        return tableView
    }()

    private lazy var tokenFilterView: DropDownView<SortTokensParam> = {
        let view = DropDownView(viewModel: .init(selectionItems: SortTokensParam.allCases, selected: viewModel.sortTokensParam))
        view.delegate = self
        
        return view
    }()
    private var bottomConstraint: NSLayoutConstraint!
    private lazy var keyboardChecker = KeyboardChecker(self, resetHeightDefaultValue: 0, ignoreBottomSafeArea: true)
    private var cancelable = Set<AnyCancellable>()
    private let sortTokensParam = PassthroughSubject<SortTokensParam, Never>()
    private let searchText = PassthroughSubject<String?, Never>()
    private let isSearchActive = PassthroughSubject<Bool, Never>()

    weak var delegate: AddHideTokensViewControllerDelegate?

    init(viewModel: AddHideTokensViewModel) {
        self.viewModel = viewModel
        searchController = UISearchController(searchResultsController: nil)
        super.init(nibName: nil, bundle: nil)

        searchController.delegate = self

        emptyView = EmptyView.addHideTokensEmptyView(completion: { [weak self] in
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
        edgesForExtendedLayout = []
        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        setupFilteringWithKeyword()

        bind(viewModel: viewModel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        keyboardChecker.viewWillAppear()
        reload()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        keyboardChecker.viewWillDisappear()
    }

    override func viewDidLayoutSubviews() {
        configureSearchBarOnce()
    }

    private func bind(viewModel: AddHideTokensViewModel) {
        title = viewModel.title

        tokenFilterView.configure(viewModel: .init(selectionItems: SortTokensParam.allCases, selected: viewModel.sortTokensParam))

        let input = AddHideTokensViewModelInput(
            sortTokensParam: sortTokensParam.eraseToAnyPublisher(),
            searchText: searchText.eraseToAnyPublisher(),
            isSearchActive: isSearchActive.eraseToAnyPublisher())

        let output = viewModel.transform(input: input)
        output.viewState
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancelable)
    }

    private func reload() {
        startLoading(animated: false)
        tableView.reloadData()
        endLoading(animated: false)
    }
}

extension AddHideTokensViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        delegate?.didClose(in: self)
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
        switch viewModel.viewModel(for: indexPath) {
        case .undefined:
            return UITableViewCell()
        case .walletToken(let viewModel):
            let cell: WalletTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: viewModel)
            return cell
        case .popularToken(let viewModel):
            let cell: PopularTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: viewModel)

            return cell
        }
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let result: AddHideTokensViewModel.ShowHideTokenResult
        switch editingStyle {
        case .insert:
            result = viewModel.markTokenAsDisplayed(at: indexPath)
        case .delete:
            result = viewModel.markTokenAsHidden(at: indexPath)
        case .none:
            result = .value(nil)
        @unknown default:
            result = .value(nil)
        }

        switch result {
        case .value(let result):
            if let result = result {
                tableView.performBatchUpdates({
                    tableView.insertRows(at: [result.indexPathToInsert], with: .automatic)
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                }, completion: nil)
            } else {
                tableView.reloadData()
            }
        case .publisher(let publisher):
            self.displayLoading()

            publisher.sink(receiveCompletion: { result in
                if case .failure = result {
                    self.displayError(message: R.string.localizable.walletsHideTokenErrorAddTokenFailure())
                }

                tableView.reloadData()

                self.hideLoading()
            }, receiveValue: { _ in
                //no-op
            }).store(in: &cancelable)
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let title = R.string.localizable.walletsHideTokenTitle()
        let hideAction = UIContextualAction(style: .destructive, title: title) { [viewModel] _, _, completionHandler in
            switch viewModel.markTokenAsHidden(at: indexPath) {
            case .value(let result):
                if let result = result {
                    tableView.performBatchUpdates({
                        tableView.deleteRows(at: [indexPath], with: .automatic)
                        tableView.insertRows(at: [result.indexPathToInsert], with: .automatic)
                    }, completion: nil)

                    completionHandler(true)
                } else {
                    tableView.reloadData()

                    completionHandler(false)
                }
            case .publisher:
                break
            }
        }

        hideAction.backgroundColor = Configuration.Color.Semantic.dangerBackground
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

        sortTokensParam.send(filterParam)
    }
}

extension AddHideTokensViewController: UISearchControllerDelegate {
    func willPresentSearchController(_ searchController: UISearchController) {
        isSearchActive.send(true)
    }

    func willDismissSearchController(_ searchController: UISearchController) {
        isSearchActive.send(false)
    }
}

extension AddHideTokensViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        DispatchQueue.main.async { [searchText] in
            searchText.send(searchController.searchBar.text ?? "")
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
        v.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        tableView.backgroundView = v
    }

    private func fixNavigationBarAndStatusBarBackgroundColorForiOS13Dot1() {
        view.superview?.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
    }

    private func setupFilteringWithKeyword() {
        wireUpSearchController()
        fixTableViewBackgroundColor()
        fixNavigationBarAndStatusBarBackgroundColorForiOS13Dot1()
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
