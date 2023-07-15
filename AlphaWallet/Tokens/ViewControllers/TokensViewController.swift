// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Combine
import AlphaWalletAttestation
import AlphaWalletFoundation

protocol TokensViewControllerDelegate: AnyObject {
    func viewWillAppear(in viewController: UIViewController)
    func didSelect(token: Token, in viewController: UIViewController)
    func didSelect(attestation: Attestation, in viewController: UIViewController)
    func didTapOpenConsole(in viewController: UIViewController)
    func walletConnectSelected(in viewController: UIViewController)
    func buyCryptoSelected(in viewController: UIViewController)
}

final class TokensViewController: UIViewController {
    private var cancellable = Set<AnyCancellable>()
    private let appear = PassthroughSubject<Void, Never>()
    private let selection = PassthroughSubject<TokensViewModel.SelectionSource, Never>()
    private let viewModel: TokensViewModel

    lazy private var filterView: ScrollableSegmentedControl = {
        let control = ScrollableSegmentedControl(cells: viewModel.filterViewModel.cells, configuration: viewModel.filterViewModel.configuration)
        control.setSelection(cellIndex: 0, animated: false)
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    private let emptyTableView: EmptyTableView = {
        let view = EmptyTableView(title: "", image: R.image.activities_empty_list()!, heightAdjustment: 0)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    private lazy var emptyTableViewHeightConstraint: NSLayoutConstraint = {
        return emptyTableView.centerYAnchor.constraint(equalTo: tableView.centerYAnchor, constant: 0)
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView.buildGroupedTableView()

        tableView.register(FungibleTokenViewCell.self)
        tableView.register(EthTokenViewCell.self)
        tableView.register(NonFungibleTokenViewCell.self)
        tableView.register(ServerTableViewCell.self)
        tableView.register(OpenSeaNonFungibleTokenPairTableCell.self)
        tableView.register(AttestationViewCell.self)

        tableView.registerHeaderFooterView(GeneralTableViewSectionHeader<ScrollableSegmentedControl>.self)
        tableView.registerHeaderFooterView(GeneralTableViewSectionHeader<AddHideTokensView>.self)
        tableView.registerHeaderFooterView(ActiveWalletSessionView.self)
        tableView.registerHeaderFooterView(GeneralTableViewSectionHeader<WalletSummaryView>.self)
        tableView.registerHeaderFooterView(GeneralTableViewSectionHeader<DummySearchView>.self)
        tableView.estimatedRowHeight = DataEntry.Metric.TableView.estimatedRowHeight
        tableView.separatorInset = .zero
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.refreshControl = refreshControl

        return tableView
    }()
    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        return control
    }()
    private (set) lazy var blockieImageView: BlockieImageView = BlockieImageView(viewSize: .init(width: 44, height: 44), imageSize: .init(width: 24, height: 24))
    private lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.delegate = self
        searchController.hidesNavigationBarDuringPresentation = false

        return searchController
    }()
    private lazy var consoleButton: UIButton = {
        let consoleButton = tableViewHeader.consoleButton
        consoleButton.titleLabel?.font = Fonts.regular(size: 22)
        consoleButton.setTitleColor(Configuration.Color.Semantic.defaultForegroundText, for: .normal)
        consoleButton.setTitle(R.string.localizable.tokenScriptShowErrors(), for: .normal)
        consoleButton.bounds.size.height = 44
        consoleButton.isHidden = true

        return consoleButton
    }()
    private var promptBackupWalletViewHolder: UIView {
        return tableViewHeader.promptBackupWalletViewHolder
    }
    private var shouldHidePromptBackupWalletViewHolderBecauseSearchIsActive = false
    private var tableViewHeader = {
        return TableViewHeader(consoleButton: UIButton(type: .system), promptBackupWalletViewHolder: UIView())
    }()
    private var isSearchBarConfigured = false
    private lazy var bottomConstraint: NSLayoutConstraint = {
        return tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    }()

    private lazy var keyboardChecker: KeyboardChecker = {
        let keyboardChecker = KeyboardChecker(self, resetHeightDefaultValue: 0, ignoreBottomSafeArea: true)
        keyboardChecker.constraints = [bottomConstraint]

        return keyboardChecker
    }()

    private var isConsoleButtonHidden: Bool {
        get { consoleButton.isHidden }
        set {
            guard newValue != isConsoleButtonHidden else { return }
            consoleButton.isHidden = newValue
            adjustTableViewHeaderHeightToFitContents()
        }
    }

    private var isPromptBackupWalletViewHolderHidden: Bool {
        get { promptBackupWalletViewHolder.isHidden }
        set {
            guard newValue != isPromptBackupWalletViewHolderHidden else { return }
            promptBackupWalletViewHolder.isHidden = newValue
            adjustTableViewHeaderHeightToFitContents()
        }
    }

    weak var delegate: TokensViewControllerDelegate?

    var promptBackupWalletView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let promptBackupWalletView = promptBackupWalletView {
                promptBackupWalletView.translatesAutoresizingMaskIntoConstraints = false
                promptBackupWalletViewHolder.addSubview(promptBackupWalletView)
                NSLayoutConstraint.activate([
                    promptBackupWalletView.anchorsConstraint(to: promptBackupWalletViewHolder, edgeInsets: .init(top: 7, left: 7, bottom: 4, right: 7)),
                ])

                isPromptBackupWalletViewHolderHidden = shouldHidePromptBackupWalletViewHolderBecauseSearchIsActive
            } else {
                isPromptBackupWalletViewHolderHidden = true
            }
        }
    }
    private var walletSummaryView = WalletSummaryView(edgeInsets: .init(top: 10, left: 0, bottom: 0, right: 0), spacing: 0)
    private lazy var searchBarHeader: DummySearchView = {
        let searchBarHeader = DummySearchView(closure: { [weak self] in
            self?.enterSearchMode()
        })

        return searchBarHeader
    }()
    private lazy var dataSource = makeDataSource()
    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
    private lazy var footerBar: ButtonsBarBackgroundView = {
        let result = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0)
        result.backgroundColor = viewModel.buyButtonFooterBarBackgroundColor
        return result
    }()

    init(viewModel: TokensViewModel) {
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)
        tableView.addSubview(emptyTableView)
        view.addSubview(footerBar)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            bottomConstraint,
            emptyTableView.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyTableViewHeightConstraint,
            footerBar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupFilteringWithKeyword()

        tableView.delegate = self

        filterView.addTarget(self, action: #selector(didTapSegment), for: .touchUpInside)
        consoleButton.addTarget(self, action: #selector(openConsole), for: .touchUpInside)

        buttonsBar.configure(.primary(buttons: 1))
        buttonsBar.buttons[0].addTarget(self, action: #selector(buyCryptoSelected), for: .touchUpInside)

        bind(viewModel: viewModel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.applyTintAdjustment()
        hidesBottomBarWhenPushed = false
        appear.send(())
        fixNavigationBarAndStatusBarBackgroundColorForiOS13Dot1()
        keyboardChecker.viewWillAppear()
        delegate?.viewWillAppear(in: self)
        hideNavigationBarTopSeparatorLine()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        keyboardChecker.viewWillDisappear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        showNavigationBarTopSeparatorLine()
    }

    @objc func openConsole() {
        delegate?.didTapOpenConsole(in: self)
    }

    @objc func buyCryptoSelected(_ sender: UIButton) {
        delegate?.buyCryptoSelected(in: self)
    }

    override func viewDidLayoutSubviews() {
        //viewDidLayoutSubviews() is called many times
        configureSearchBarOnce()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func showOrHideBackupWalletViewHolder() {
        isPromptBackupWalletViewHolderHidden = !(viewModel.shouldShowBackupPromptViewHolder && !promptBackupWalletViewHolder.subviews.isEmpty) || shouldHidePromptBackupWalletViewHolderBecauseSearchIsActive
    }

    private func bind(viewModel: TokensViewModel) {
        navigationItem.largeTitleDisplayMode = viewModel.largeTitleDisplayMode
        view.backgroundColor = viewModel.backgroundColor
        tableView.backgroundColor = viewModel.backgroundColor

        buttonsBar.buttons[0].setTitle(viewModel.buyCryptoTitle, for: .normal)

        let input = TokensViewModelInput(
            appear: appear.eraseToAnyPublisher(),
            pullToRefresh: refreshControl.publisher(forEvent: .valueChanged).eraseToAnyPublisher(),
            selection: selection.eraseToAnyPublisher(),
            keyboard: keyboardChecker.publisher)

        let output = viewModel.transform(input: input)

        dataSource.numberOfRowsInSection
            .sink { [weak self, viewModel] section in
                guard viewModel.sections[section] == .tokens || viewModel.sections[section] == .collectiblePairs else { return }
                self?.handleTokensCountChange(rows: viewModel.numberOfItems(for: section))
            }.store(in: &cancellable)

        output.viewState
            .sink { [weak self, weak walletSummaryView, blockieImageView, navigationItem] state in
                self?.showOrHideBackupWalletViewHolder()

                walletSummaryView?.configure(viewModel: .init(walletSummary: state.summary, alignment: .center))
                blockieImageView.set(blockieImage: state.blockiesImage)

                navigationItem.title = state.title
                self?.isConsoleButtonHidden = state.isConsoleButtonHidden
                self?.footerBar.isHidden = state.isFooterHidden
                self?.applySnapshot(with: state.sections, animatingDifferences: false)
            }.store(in: &cancellable)

        output.deletion
            .sink { [dataSource] indexPaths in
                var snapshot = dataSource.snapshot()

                let ids = indexPaths.compactMap { dataSource.itemIdentifier(for: $0) }
                snapshot.deleteItems(ids)

                dataSource.apply(snapshot, animatingDifferences: true)
            }.store(in: &cancellable)

        output.pullToRefreshState
            .sink { [refreshControl] state in
                switch state {
                case .endLoading: refreshControl.endRefreshing()
                case .beginLoading: refreshControl.beginRefreshing()
                }
            }.store(in: &cancellable)

        output.selection
            .sink { [weak self] tokenOrAttestation in
                guard let strongSelf = self else { return }
                switch tokenOrAttestation {
                case .token(let token):
                    strongSelf.delegate?.didSelect(token: token, in: strongSelf)
                case .attestation(let attestation):
                    strongSelf.delegate?.didSelect(attestation: attestation, in: strongSelf)
                }
            }.store(in: &cancellable)

        output.applyTableInset
            .map { [footerBar] hasInset -> UIEdgeInsets in
                switch hasInset {
                case .some(let noNeedInInset): return noNeedInInset ? UIEdgeInsets.zero : UIEdgeInsets(top: 0, left: 0, bottom: footerBar.height, right: 0)
                case .none: return UIEdgeInsets.zero
                }
            }.removeDuplicates()
            .sink { [tableView] in
                tableView.contentInset = $0
                tableView.scrollIndicatorInsets = $0
            }.store(in: &cancellable)
    }

    private func adjustTableViewHeaderHeightToFitContents() {
        let size = tableViewHeader.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        tableViewHeader.bounds.size.height = size.height
        tableView.tableHeaderView = tableViewHeader
    }

    @objc private func enterSearchMode() {
        let searchController = searchController
        navigationItem.searchController = searchController

        viewModel.set(isSearchActive: true)

        DispatchQueue.main.async {
            searchController.isActive = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                searchController.searchBar.becomeFirstResponder()
            }
        }
    }
}

extension TokensViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        selection.send(.cell(indexPath: indexPath))
    }

    //Hide the footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return viewModel.heightForHeaderInSection(for: section)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch viewModel.sections[section] {
        case .walletSummary:
            let header: TokensViewController.GeneralTableViewSectionHeader<WalletSummaryView> = tableView.dequeueReusableHeaderFooterView()
            header.subview = walletSummaryView

            return header
        case .filters:
            let header: TokensViewController.GeneralTableViewSectionHeader<ScrollableSegmentedControl> = tableView.dequeueReusableHeaderFooterView()
            header.subview = filterView
            header.useSeparatorLine = false

            return header
        case .activeWalletSession:
            let header: ActiveWalletSessionView = tableView.dequeueReusableHeaderFooterView()
            header.configure(viewModel: .init(count: viewModel.walletConnectSessions))
            header.delegate = self

            return header
        case .search:
            let header: TokensViewController.GeneralTableViewSectionHeader<DummySearchView> = tableView.dequeueReusableHeaderFooterView()
            header.useSeparatorLine = false
            header.subview = searchBarHeader

            return header
        case .tokens, .collectiblePairs:
            return nil
        }
    }

    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        hideNavigationBarTopSeparatorLineInScrollEdgeAppearance()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        scrollView.contentOffset.y == 0 ? hideNavigationBarTopSeparatorLineInScrollEdgeAppearance() : showNavigationBarTopSeparatorLineInScrollEdgeAppearance()
    }

}

extension TokensViewController: ActiveWalletSessionViewDelegate {

    func view(_ view: ActiveWalletSessionView, didSelectTap sender: UITapGestureRecognizer) {
        delegate?.walletConnectSelected(in: self)
    }
}

extension TokensViewController {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return viewModel.cellHeight(for: indexPath)
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? OpenSeaNonFungibleTokenPairTableCell else { return }

        cell.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: .greatestFiniteMagnitude)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        return viewModel.trailingSwipeActionsConfiguration(for: indexPath)
    }

    private func handleTokensCountChange(rows: Int) {
        let isEmpty = rows == 0
        if isEmpty {
            if let height = tableHeight() {
                emptyTableViewHeightConstraint.constant = height / 2.0
            } else {
                emptyTableViewHeightConstraint.constant = 0
            }
            emptyTableView.title = viewModel.emptyTokensTitle
        }
        emptyTableView.isHidden = !isEmpty
    }

    private func tableHeight() -> CGFloat? {
        guard let delegate = tableView.delegate else { return nil }
        let sectionCount = viewModel.sections.count
        var height: CGFloat = 0
        for sectionIndex in 0..<sectionCount {
            let rows = viewModel.numberOfItems(for: sectionIndex)
            for rowIndex in 0..<rows {
                height += (delegate.tableView?(tableView, heightForRowAt: IndexPath(row: rowIndex, section: sectionIndex))) ?? 0
            }
            height += (delegate.tableView?(tableView, heightForHeaderInSection: sectionIndex)) ?? 0
            height += (delegate.tableView?(tableView, heightForFooterInSection: sectionIndex)) ?? 0
        }
        return height
    }
}

fileprivate extension TokensViewController {
    func makeDataSource() -> TableViewDiffableDataSource<TokensViewModel.Section, TokensViewModel.ViewModelType> {
        return TableViewDiffableDataSource(tableView: tableView, cellProvider: { [weak self] tableView, indexPath, viewModel in
            guard let strongSelf = self else { return UITableViewCell() }
            switch viewModel {
            case .undefined:
                return UITableViewCell()
            case .nftCollection(let viewModel):
                let cell: OpenSeaNonFungibleTokenPairTableCell = tableView.dequeueReusableCell(for: indexPath)
                cell.delegate = strongSelf
                cell.configure(viewModel: viewModel)

                return cell
            case .nonFungible(let viewModel):
                let cell: NonFungibleTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: viewModel)

                return cell
            case .fungibleToken(let viewModel):
                let cell: FungibleTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: viewModel)

                return cell
            case .nativeCryptocurrency(let viewModel):
                let cell: EthTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: viewModel)

                return cell
            case .rpcServer(let viewModel):
                let cell: ServerTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: viewModel)

                return cell
            case .attestation(let viewModel):
                let cell: AttestationViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: viewModel)
                return cell
            }
        })
    }

    private func applySnapshot(with viewModels: [TokensViewModel.SectionViewModel], animatingDifferences: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<TokensViewModel.Section, TokensViewModel.ViewModelType>()
        let sections = viewModels.map { $0.section }
        snapshot.appendSections(sections)

        for each in viewModels {
            snapshot.appendItems(each.views, toSection: each.section)
        }

        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }
}

extension TokensViewController {
    @objc func didTapSegment(_ control: ScrollableSegmentedControl) {
        guard let filter = viewModel.convertSegmentedControlSelectionToFilter(control.selectedSegment) else { return }
        apply(filter: filter, withSegmentAtSelection: control.selectedSegment)
    }

    private func apply(filter: WalletFilter, withSegmentAtSelection selection: ControlSelection?) {
        let previousFilter = viewModel.filter
        viewModel.set(filter: filter)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [filterView] in
            //Important to update the segmented control (and hence add the segmented control back to the table) after they have been re-added to the table header through the table reload. Otherwise adding to the table header will break the animation for segmented control
            if let selection = selection, case let ControlSelection.selected(index) = selection {
                filterView.setSelection(cellIndex: Int(index))
            }
        }
        //Exit search if user tapped on the wallet filter. Careful to not trigger an infinite recursion between changing the filter by "category" and search keywords which are all based on filters
        if previousFilter == filter {
            //do nothing
        } else {
            switch filter {
            case .all, .defi, .governance, .assets, .collectiblesOnly, .filter, .attestations:
                searchController.isActive = false
            case .keyword:
                break
            }
        }
    }
}

extension TokensViewController: UISearchControllerDelegate {

    func didDismissSearchController(_ searchController: UISearchController) {
        guard viewModel.isSearchActive else { return }

        navigationItem.searchController = nil

        viewModel.set(isSearchActive: false)
    }
}

extension TokensViewController: UISearchResultsUpdating {
    //At least on iOS 13 beta on a device. updateSearchResults(for:) is called when we set `searchController.isActive = false` to dismiss search (because user tapped on a filter), but the value of `searchController.isActive` remains `false` during the call, hence the async.
    //This behavior is not observed in iOS 12, simulator
    func updateSearchResults(for searchController: UISearchController) {
        DispatchQueue.main.async {
            self.processSearchWithKeywords()
        }
    }

    private func processSearchWithKeywords() {
        shouldHidePromptBackupWalletViewHolderBecauseSearchIsActive = searchController.isActive
        guard searchController.isActive else {
            switch viewModel.filter {
            case .all, .defi, .governance, .assets, .collectiblesOnly, .filter, .attestations:
                break
            case .keyword:
                //Handle when user taps Cancel button to stop search
                setDefaultFilter()
            }
            return
        }
        let keyword = searchController.searchBar.text ?? ""
        updateResults(withKeyword: keyword)
    }

    private func updateResults(withKeyword keyword: String) {
        filterView.unselect()
        apply(filter: .keyword(keyword), withSegmentAtSelection: nil)
    }

    private func setDefaultFilter() {
        apply(filter: .all, withSegmentAtSelection: .selected(0))
    }
}

extension TokensViewController: OpenSeaNonFungibleTokenPairTableCellDelegate {

    func didSelect(cell: OpenSeaNonFungibleTokenPairTableCell, indexPath: IndexPath, isLeftCardSelected: Bool) {
        selection.send(.gridItem(indexPath: indexPath, isLeftCardSelected: isLeftCardSelected))
    }
}

///Support searching/filtering tokens with keywords. This extension is set up so it's easier to copy and paste this functionality elsewhere
extension TokensViewController {
    private func makeSwitchToAnotherTabWorkWhileFiltering() {
        definesPresentationContext = true
    }

    private func wireUpSearchController() {
        searchController.searchResultsUpdater = self
    }

    private func fixNavigationBarAndStatusBarBackgroundColorForiOS13Dot1() {
        view.superview?.backgroundColor = viewModel.backgroundColor
    }

    private func setupFilteringWithKeyword() {
        navigationItem.hidesSearchBarWhenScrolling = false
        wireUpSearchController()
        TokensViewController.functional.fixTableViewBackgroundColor(tableView: tableView, backgroundColor: viewModel.backgroundColor)
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

// MARK: Search
extension TokensViewController {
    override var keyCommands: [UIKeyCommand]? {
        return [UIKeyCommand(input: "f", modifierFlags: .command, action: #selector(enterSearchMode))]
    }
}

extension TokensViewController {
    enum functional {}
}

extension TokensViewController.functional {
    static func fixTableViewBackgroundColor(tableView: UITableView, backgroundColor: UIColor) {
        let v = UIView()
        v.backgroundColor = backgroundColor
        tableView.backgroundView?.backgroundColor = backgroundColor
        tableView.backgroundView = v
    }
}

extension UISearchBar {
    static func configure(searchBar: UISearchBar, backgroundColor: UIColor = Configuration.Color.Semantic.searchBarBackground) {
        if let placeholderLabel = searchBar.firstSubview(ofType: UILabel.self) {
            placeholderLabel.textColor = Configuration.Color.Semantic.searchbarPlaceholder
        }
        if let textField = searchBar.firstSubview(ofType: UITextField.self) {
            textField.textColor = Configuration.Color.Semantic.defaultForegroundText
            if let imageView = textField.leftView as? UIImageView {
                imageView.image = imageView.image?.withRenderingMode(.alwaysTemplate)
                imageView.tintColor = Configuration.Color.Semantic.defaultForegroundText
            }
        }
        //Hack to hide the horizontal separator below the search bar
        searchBar.superview?.firstSubview(ofType: UIImageView.self)?.isHidden = true
        //Remove border line
        searchBar.layer.borderWidth = 1
        searchBar.layer.borderColor = Configuration.Color.Semantic.borderClear.cgColor
        searchBar.backgroundImage = UIImage()
        searchBar.placeholder = R.string.localizable.tokensSearchbarPlaceholder()
        searchBar.backgroundColor = backgroundColor
    }
}
